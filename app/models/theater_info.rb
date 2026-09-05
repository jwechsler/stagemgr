# frozen_string_literal: true

# Simple, non-editorial facts about the house running this install: phone,
# street address, ticket-pickup window, social links, who signs the mail.
#
# These come from the `theater:` block of config/server.yml -- deployment
# configuration, not database records, because they are read on nearly every
# public page and every email and they change about once a decade. Editorial
# copy (anything with a voice) belongs in a site theme instead; see
# sites/README.md for where a given string goes.
#
# The house *name* is deliberately not a config key. It is the name of the
# Default theater row, so the one proper noun that appears in dozens of places
# has a single source that the box office already maintains. Renaming that row
# renames the house everywhere, which is the intended behaviour.
#
# Every fact may be nil. Callers guard the sentence that would use one rather
# than printing a blank; a house that has not configured a phone number should
# see no "call us" sentence at all.
#
# A plain object with no state worth sharing: build one per render (see
# ApplicationHelper#theater_info) rather than memoizing one process-wide, so a
# changed Default theater row is picked up on the next request.
class TheaterInfo
  # Raised when this install has no address it could possibly send mail from.
  class MissingAddress < StandardError; end

  CONFIG_KEY = 'theater'

  MISSING_ADDRESS_MESSAGE =
    'This install has no address to send mail from. Set `email: addresses: box_office:` (or at least ' \
    '`software_address:`) in config/server.yml, or config.action_mailer.default_options[:from].'

  # Every key readable straight from the `theater:` block. Some have a fallback
  # and are redefined below.
  FACTS = %i[
    phone
    street_address
    city_state_zip
    pickup_window_text
    doors_open_minutes_before
    website_url
    facebook_url
    twitter_url
    instagram_url
    logo_url
    mailing_list_blurb
    box_office_display_name
    artistic_director_name
    artistic_director_title
    artistic_director_email
    signature_image_url
    stripe_billing_portal_url
  ].freeze

  FACTS.each do |fact|
    define_method(fact) { self[fact] }
  end

  # +server_config+ and +email_addresses+ are injectable so specs can describe a
  # house without editing the developer's own (gitignored) config/server.yml.
  def initialize(server_config: nil, email_addresses: nil)
    @server_config = server_config || Rails.configuration.x.server_config || {}
    @email_addresses = email_addresses || Rails.configuration.x.email_address || {}
  end

  # One configured fact, or nil when it is missing or blank. Raises KeyError for
  # anything not in FACTS: a mistyped key that quietly returned nil would drop a
  # sentence from a page with nothing to show for it.
  def [](key)
    unless FACTS.include?(key.to_sym)
      raise KeyError, "#{key.inspect} is not a theater fact. Known facts: #{FACTS.join(', ')}"
    end

    lookup(facts, key).presence
  end

  # The house's proper name. Falls back to the application display name so that
  # a brand-new install with no theater row yet still renders sentences.
  def name
    @name ||= default_theater&.name.presence || Rails.configuration.x.app_display_name
  end

  # The Default theater row, or nil before one exists. Memoized including nil:
  # a fresh install would otherwise query on every fact that falls back.
  def default_theater
    return @default_theater if defined?(@default_theater)

    @default_theater = Theater.default_theater
  end

  # The marketing site. Configured URL first, then whatever the Default theater
  # row carries, so an install that filled in only the admin form still links.
  def website_url
    self[:website_url] || default_theater&.url.presence
  end

  # "Wilma Theater Box Office" unless the house spells it differently.
  def box_office_display_name
    self[:box_office_display_name] || "#{name} Box Office"
  end

  # Minutes, however the operator typed it: YAML hands back an Integer for
  # `30` and a String for `"30"`.
  def doors_open_minutes_before
    self[:doors_open_minutes_before]&.to_i
  end

  # "1229 W Belmont, Chicago, IL 60657", or nil when neither half is set.
  def full_address
    [street_address, city_state_zip].compact_blank.join(', ').presence
  end

  # Is there a named person to sign mail as? Both halves are needed: a name
  # with no address cannot be a From: header, and an address with no name
  # reads as a robot.
  def artistic_director?
    artistic_director_name.present? && artistic_director_email.present?
  end

  # The box office address, from the existing `email: addresses: box_office:`
  # key rather than a second copy in the `theater:` block.
  def box_office_email
    lookup(@email_addresses, :box_office).presence
  end

  # RFC-2822 From: headers, e.g. `"Wilma Box Office" <boxoffice@wilma.org>`.
  #
  # Never nil. ActionMailer merges its defaults with reverse_merge, so an
  # explicit `from: nil` is a *value* -- it wins over the default and sends a
  # message with no From: header at all, which the receiving MTA is entitled to
  # bounce. So this falls back down the chain and, if even that runs dry,
  # raises somewhere the operator can act on rather than sending junk.
  def box_office_from
    address_header(box_office_display_name, sender_address)
  end

  # The artistic director signs follow-up mail; a house with no artistic
  # director configured sends it from the box office instead.
  def artistic_director_from
    return box_office_from unless artistic_director?

    address_header(artistic_director_name, artistic_director_email)
  end

  private

  # Whatever this install can legitimately send as: the box office, then the
  # software address every deployment has to set anyway, then ActionMailer's own
  # default. All three configured empty is a broken install, not a runtime
  # condition to paper over.
  def sender_address
    box_office_email ||
      lookup(@email_addresses, :software_address).presence ||
      default_mailer_from ||
      raise(MissingAddress, MISSING_ADDRESS_MESSAGE)
  end

  def default_mailer_from
    return nil unless defined?(ActionMailer::Base)

    ActionMailer::Base.default[:from].presence
  end

  def facts
    @facts ||= begin
      raw = lookup(@server_config, CONFIG_KEY) || {}
      raw.respond_to?(:[]) ? raw : {}
    end
  end

  # server.yml parses to string keys (with_indifferent_access in the app), but
  # specs and callers pass symbols freely.
  def lookup(source, key)
    return nil unless source.respond_to?(:[])

    value = source[key.to_s]
    value.nil? ? source[key.to_sym] : value
  end

  def address_header(display_name, email)
    address = Mail::Address.new(email)
    address.display_name = display_name if display_name.present?
    address.format
  rescue Mail::Field::ParseError
    # A misconfigured address should still send from *something* the operator
    # can recognise in the logs, rather than raising mid-order.
    email
  end
end
