# frozen_string_literal: true

module Lgl
  # Makes an unlinked LGL constituent a Stagemgr customer. Used by
  # Lgl::Reconciler when a constituent's external id is junk and no address is
  # tagged with it. Never calls LGL: the caller enqueues the LglSyncAddressJob
  # that writes the new address's id into LGL.
  #
  #   organisation (is_org)            -> :org_skipped
  #   neither an email nor a street    -> :no_contact
  #   neither a first nor a last name  -> :no_name
  #   one address matches by email and last name (match_by_email), or
  #   several do and exactly one of them shares the constituent's first name
  #   (NameMatch: first word only, so couples' and spouses' records and
  #   middle initials do not confuse it)
  #                                    -> tag it LGL ID, clear its review: :linked
  #   several share the first name     -> review only those, "matches several
  #                                       customers named First Last by email":
  #                                       spellings of one person, merge them
  #   several match, none shares it (or the constituent has no first name)
  #                                    -> review each, "matches several
  #                                       customers by email and last name"
  #                                       (:review either way)
  #
  #   Before linking or reviewing, every candidate loses a several-matches
  #   review naming this constituent, so a spouse flagged earlier or an old
  #   wording does not linger.
  #   none                             -> create a tagged address: :created
  #                                       (:invalid_email when LGL's email is
  #                                       not one Address accepts;
  #                                       :already_tagged when another run
  #                                       tagged one first)
  class ConstituentReplicator
    Result = Struct.new(:outcome, :address)

    # Common start of both several-matches review reasons (after "LGL
    # constituent N "); the LGL Sync page spots it to link the customer to
    # their same-named duplicates, and LglSyncAddressJob clears it once the
    # address is linked to N.
    SEVERAL_MATCHES_REASON = 'matches several customers'

    # Why the constituent is never replicated, or nil.
    def self.skip_reason(constituent)
      return :org_skipped if constituent['is_org'] == true
      return :no_contact if emails(constituent).empty? && Array(constituent['street_addresses']).empty?
      return :no_name if full_name(constituent).empty?

      nil
    end

    # Live, non-placeholder addresses with one of the constituent's emails and
    # its last name (case-insensitive) that carry no other LGL ID.
    def self.candidates(constituent)
      emails = emails(constituent)
      last_name = constituent['last_name'].to_s.strip
      return [] if emails.empty? || last_name.empty?

      lgl_id = constituent['id'].to_s
      Address.where(email: emails, placeholder: false).order(:id).select do |address|
        last_name.casecmp?(address.last_name.to_s.strip) && [nil, lgl_id].include?(address.lgl_id)
      end
    end

    # [outcome, the single matching address or nil, the addresses to flag for
    # review (empty unless :several_matches)]; outcome is :one_match,
    # :several_matches, :no_match or :no_email. Several email + last name
    # matches are narrowed by first name (NameMatch).
    def self.match_by_email(constituent)
      return [:no_email, nil, []] if emails(constituent).empty?

      found = candidates(constituent)
      return [:no_match, nil, []] if found.empty?
      return [:one_match, found.first, []] if found.one?

      named = NameMatch.narrow(constituent['first_name'], found, &:first_name)
      return [:one_match, named.first, []] if named&.one?

      [:several_matches, nil, named.presence || found]
    end

    # How every several-matches review for constituent +lgl_id+ begins.
    def self.several_matches_prefix(lgl_id)
      "LGL constituent #{lgl_id} #{SEVERAL_MATCHES_REASON}"
    end

    # The LGL Review reason for +flagged+ (match_by_email's third element).
    def self.several_matches_reason(constituent, flagged)
      prefix = several_matches_prefix(constituent['id'])
      first_name = constituent['first_name'].to_s.strip
      if flagged.all? { |address| NameMatch.same_first_name?(first_name, address.first_name) }
        "#{prefix} named #{full_name(constituent)} by email: merge them in Stagemgr, then Re-sync"
      else
        "#{prefix} by email and last name"
      end
    end

    # An unsaved, untagged Address: name as Lgl::ContactPull pulls it, and the
    # preferred (else first) email, street and phone.
    def self.build_address(constituent)
      address = Address.new(full_name: full_name(constituent), placeholder: false)
      email = first_preferred(constituent['email_addresses'])
      address.email = email['address'].to_s.strip if email
      street = first_preferred(constituent['street_addresses'])
      address.assign_attributes(Lgl::ContactPull.street_fields_from(street)) if street
      phone = first_preferred(constituent['phone_numbers'])
      address.phone = phone['number'].to_s.strip if phone
      address
    end

    # True when +address+ fails validation on its email and nothing else.
    def self.invalid_email?(address)
      !address.valid? && address.errors.attribute_names == [:email]
    end

    def self.emails(constituent)
      Array(constituent['email_addresses']).filter_map { |e| e['address'].to_s.strip.downcase.presence }.uniq
    end

    # first_name and last_name joined, as Lgl::ContactPull pulls a name.
    def self.full_name(constituent)
      [constituent['first_name'], constituent['last_name']].map { |part| part.to_s.strip }.reject(&:empty?).join(' ')
    end

    def self.first_preferred(entries)
      ContactChanges.preferred(entries) || Array(entries).first
    end
    private_class_method :emails, :first_preferred

    def initialize(constituent)
      @constituent = constituent
      @lgl_id = constituent['id'].to_s
    end

    def apply!
      skip = self.class.skip_reason(@constituent)
      return Result.new(skip, nil) if skip

      outcome, address, flagged = self.class.match_by_email(@constituent)
      case outcome
      when :one_match then link(address)
      when :several_matches then review(flagged)
      else create
      end
    end

    private

    def link(address)
      clear_stale_reviews
      address.set_lgl_id!(@lgl_id)
      address.clear_lgl_review!
      Result.new(:linked, address)
    end

    def review(flagged)
      clear_stale_reviews
      reason = self.class.several_matches_reason(@constituent, flagged)
      flagged.each { |address| address.lgl_review!(reason) }
      Result.new(:review, nil)
    end

    # Drops a several-matches review naming this constituent from every
    # address carrying one, including those that no longer match its emails
    # (Lgl::ReviewList.several_matches_addresses finds them by reason, not by
    # email); any other review still needs a person.
    def clear_stale_reviews
      Lgl::ReviewList.several_matches_addresses(@lgl_id).each(&:clear_lgl_review!)
    end

    # The re-check guards an inline rake run overlapping the poll. No early
    # return inside the transaction block: Rails 6.1 deprecates it. Matching
    # no customer still clears this constituent's old several-matches reviews.
    def create
      clear_stale_reviews
      theater_id = AddressTag.lgl_theater_id!
      Address.transaction do
        if tagged?
          Result.new(:already_tagged, nil)
        else
          save_new(self.class.build_address(@constituent), theater_id)
        end
      end
    end

    def save_new(address, theater_id)
      if self.class.invalid_email?(address)
        Rails.logger.info("[LGL] constituent #{@lgl_id}: email is not valid; no address created (fix it in LGL)")
        return Result.new(:invalid_email, nil)
      end

      address.address_tags << ImportIssuesReport.new_address_tag(theater_id, address, AddressTag::LGL_ID, @lgl_id)
      address.save!
      Rails.logger.info("[LGL] created address ##{address.id} from constituent #{@lgl_id}")
      Result.new(:created, address)
    end

    def tagged?
      AddressTag.lgl(AddressTag::LGL_ID).exists?(tag_value: @lgl_id)
    end
  end
end
