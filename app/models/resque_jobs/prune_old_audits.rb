# Deletes audit-trail rows (the audited gem's audits table) older than the
# retention window, in small batches to avoid long transactions and
# replication stalls.
#
# Deletion is irreversible, so the job refuses to delete anything not yet
# covered by an archive: rows are only deleted up to the older of (retention
# cutoff, archive marker). The marker (a JobMetadata record named
# ARCHIVE_MARKER) is advanced automatically by ArchiveOldAudits after it
# writes and verifies an export file — which itself refuses to run until
# archive_directory is set in server.yml. An operator performing a manual
# mysqldump instead can set the marker by hand to the dump's --where
# boundary (see the runbook in docs/data-retention-strategy.md).
#
# Trade-off documented in the strategy doc: orders older than the cutoff show
# no "changes" panel on their admin pages (the partial degrades gracefully).
class PruneOldAudits
  @queue = :maintenance

  RETENTION_YEARS = 3
  ARCHIVE_MARKER = 'audits_archived_through'.freeze
  BATCH_SIZE = 5_000
  BATCH_PAUSE_SECONDS = 1

  def self.perform
    retention_cutoff = RETENTION_YEARS.years.ago
    archived_through = JobMetadata.last_run(ARCHIVE_MARKER)

    if archived_through <= Time.at(0)
      Rails.logger.info 'PruneOldAudits: no archive marker recorded ' \
                        "(JobMetadata '#{ARCHIVE_MARKER}'); refusing to delete. " \
                        'Run the audit archive dump runbook first.'
      return 0
    end

    cutoff = [retention_cutoff, archived_through].min
    total = 0
    loop do
      deleted = Audited::Audit.where(created_at: ...cutoff)
                              .limit(BATCH_SIZE)
                              .delete_all
      total += deleted
      break if deleted < BATCH_SIZE

      sleep BATCH_PAUSE_SECONDS
    end
    Rails.logger.info "PruneOldAudits: deleted #{total} audits created before #{cutoff.to_date}"
    total
  end
end
