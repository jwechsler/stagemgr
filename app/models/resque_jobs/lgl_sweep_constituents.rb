# frozen_string_literal: true

# Nightly: lists every LGL constituent id and, for each default-theater LGL ID
# tag naming an id that is not in the list, confirms with a direct lookup.
# Only a confirmed 404 (deleted, or merged away in LGL) drops the tag and
# enqueues the address's LglSyncAddressJob (reason 'sweep'), which
# re-resolves it by external id and email. Only reads LGL.
#
# An incomplete listing (fewer ids than LGL's total_items) aborts before any
# tag is touched.
class LglSweepConstituents
  @queue = :lgl

  include LoggedJob

  COMPLETED = 'lgl_sweep_completed'
  REASON = 'sweep'

  def self.perform
    return unless Lgl.enabled?

    client = Lgl.client
    present = complete_id_set(client)
    counts = Hash.new(0)
    missing_tags(present).each { |address_id, lgl_id| counts[confirm(client, address_id, lgl_id)] += 1 }
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
    theater_id = Theater.default_theater&.id
    return [] if theater_id.nil?

    AddressTag.where(tag_label: AddressTag::LGL_ID, theater_id: theater_id)
              .order(:id).pluck(:address_id, :tag_value)
              .reject { |_address_id, lgl_id| present.include?(lgl_id.to_s.strip) }
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

    address.clear_lgl_id!
    Resque.enqueue(LglSyncAddressJob, address.id, REASON)
    :cleared
  end
end
