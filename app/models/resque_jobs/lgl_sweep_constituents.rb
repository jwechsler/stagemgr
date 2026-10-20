# frozen_string_literal: true

# Nightly: lists every LGL constituent id and, for each default-theater LGL ID
# tag naming an id that is not in the list, confirms with a direct lookup.
# Only a confirmed 404 (deleted, or merged away in LGL) enqueues the address's
# LglSyncAddressJob (reason 'sweep'), which re-resolves it by external id and
# email. The dead tag is left for that job: it is replaced when a match is
# found, and otherwise kept with an LGL Review tag, since only staff may have a
# new constituent created for a once-linked address.
#
# Then, from the same listing, clears resolved merge reviews: an "Also LGL
# constituent N" LGL Review (see LglLinkable::ALSO_CONSTITUENT_PATTERN) whose N
# is not listed while the address's own LGL ID is. Each N is confirmed with a
# direct lookup first; only a 404 clears the review (staff merged the two in
# LGL and it kept the one tagged here). A dead LGL ID is left for the pass
# above. Only reads LGL; clearing a local tag is fine in read-only too.
#
# An incomplete listing (fewer ids than LGL's total_items) aborts before any
# tag is touched.
class LglSweepConstituents
  @queue = :maintenance

  include LoggedJob

  COMPLETED = 'lgl_sweep_completed'
  REASON = 'sweep'

  def self.perform
    return Lgl.log_disabled('sweep') unless Lgl.enabled?

    client = Lgl.client
    present = complete_id_set(client)
    counts = Hash.new(0)
    missing_tags(present).each { |address_id, lgl_id| counts[confirm(client, address_id, lgl_id)] += 1 }
    resolved_merge_reviews(present).each { |address_id, other_id| counts[clear_merge_review(client, address_id, other_id)] += 1 }
    JobMetadata.record_run_at(COMPLETED, Time.current)
    Rails.logger.info("[LGL] sweep: #{present.size} constituents; " \
                      "#{counts.sort.map { |k, v| "#{k}=#{v}" }.join(' ').presence || 'every tag present'}")
    counts
  end

  def self.complete_id_set(client)
    ids, total = client.each_constituent_id
    if total.nil? || ids.size != total.to_i
      message = "LGL sweep aborted: listed #{ids.size} constituent ids but LGL reports #{total.inspect}"
      Rails.logger.error("[LGL] #{message}")
      raise Lgl::Error, message
    end
    ids.to_set(&:to_s)
  end

  # [address_id, lgl_id] for every live tag whose constituent is not listed.
  def self.missing_tags(present)
    AddressTag.lgl(AddressTag::LGL_ID).order(:id).pluck(:address_id, :tag_value)
              .reject { |_address_id, lgl_id| present.include?(lgl_id.to_s.strip) }
  end

  # [address_id, named id] for every "Also LGL constituent N" review whose N is
  # not listed and whose address's LGL ID is.
  def self.resolved_merge_reviews(present)
    like = "#{AddressTag.sanitize_sql_like(LglLinkable::ALSO_CONSTITUENT_PREFIX)} %"
    reviews = AddressTag.lgl(AddressTag::LGL_REVIEW).where('tag_value LIKE ?', like).order(:id)
                        .pluck(:address_id, :tag_value)
                        .filter_map do |address_id, reason|
                          other_id = LglLinkable.also_constituent_id(reason)
                          [address_id, other_id] if other_id && present.exclude?(other_id)
                        end
    return [] if reviews.empty?

    own_ids = lgl_ids_by_address(reviews.map(&:first))
    reviews.select { |address_id, _other_id| present.include?(own_ids[address_id]) }
  end

  # address_id => its first LGL ID tag value, stripped. Descending, so to_h
  # keeps the lowest id, as LglLinkable#lgl_id does.
  def self.lgl_ids_by_address(address_ids)
    AddressTag.lgl(AddressTag::LGL_ID).where(address_id: address_ids).order(id: :desc)
              .pluck(:address_id, :tag_value).to_h { |address_id, lgl_id| [address_id, lgl_id.to_s.strip] }
  end

  def self.clear_merge_review(client, address_id, other_id)
    return :merge_review_kept unless client.find(other_id).nil?

    address = Address.find_by(id: address_id)
    return :address_gone if address.nil?
    # The reason was plucked before the lookup; never clear a newer review.
    return :merge_review_changed unless address.lgl_review_other_constituent_id == other_id

    address.clear_lgl_review!
    :merge_review_cleared
  end

  def self.confirm(client, address_id, lgl_id)
    value = lgl_id.to_s.strip
    unless Lgl::Reconciler::NUMERIC.match?(value)
      Rails.logger.warn("[LGL] sweep: address ##{address_id} has a non-numeric LGL ID #{lgl_id.inspect}")
      return :invalid_tag
    end
    return :still_present unless client.find(value).nil?

    address = Address.find_by(id: address_id)
    return :address_gone if address.nil?

    Resque.enqueue(LglSyncAddressJob, address.id, REASON)
    :dead
  end
end
