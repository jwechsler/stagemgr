# frozen_string_literal: true

require 'stringio'

# Nightly: downloads the LGL saved report behind
# littlegreenlight.donor_tier_report_url (ENV LGL_DONOR_TIER_REPORT_URL),
# stores it as a donor levels import FileStore and queues LglDonorImport, the
# same import the Imports page runs for a manual upload. The import's result
# email goes to the FileStore's user: the Stagemgr user whose email is
# email.addresses.supervisor_notifications.
#
# Runs whenever the report link is set; it does not need the LGL API key or
# littlegreenlight.sync. JobMetadata 'LglDonorLevelsFetch' records the last
# successful download (the import records its own run as 'LglDonorImport').
#
# The link can carry a secret token, so it is never logged; download failures
# raise Lgl::Error naming only the host (Lgl::DonorLevelsDownload).
class LglDonorLevelsFetch
  @queue = :maintenance

  include LoggedJob

  NOTES = 'Donor levels from LGL (scheduled)'
  CONTENT_TYPE = 'text/csv'

  # Returns the new FileStore id, or nil when the report link is not set.
  def self.perform
    settings = Lgl.settings
    unless settings.donor_levels_enabled?
      Rails.logger.info('[LGL] donor levels fetch skipped: littlegreenlight.donor_tier_report_url is not set')
      return nil
    end

    user = recipient
    csv = Lgl::DonorLevelsDownload.fetch(settings.donor_tier_report_url)
    filestore = store(csv, user)
    Resque.enqueue(LglDonorImport, filestore.id)
    Rails.logger.info("[LGL] donor levels report stored as FileStore #{filestore.id}; import queued")
    filestore.id
  end

  def self.recipient
    email = Rails.configuration.x.email_address['supervisor_notifications']
    user = User.find_by(email: email) if email.present?
    return user if user

    raise Lgl::Error, 'Donor levels fetch: no Stagemgr user has the ' \
                      'email.addresses.supervisor_notifications address'
  end

  def self.store(csv, user)
    filestore = FileStore.new(user: user, worker: FileStore::IMPORT,
                              format: FileStore::DONATION_LEVELS_IMPORT_FORMAT, notes: NOTES)
    filestore.datafile.attach(io: StringIO.new(csv), filename: "lgl_donor_levels_#{Date.current.iso8601}.csv",
                              content_type: CONTENT_TYPE)
    filestore.save!
    filestore
  end
  private_class_method :recipient, :store
end
