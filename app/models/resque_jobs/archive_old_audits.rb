# Exports audit-trail rows that have aged past the retention window to a
# gzipped NDJSON file, then advances the archive marker that PruneOldAudits
# is gated on — so the archive→prune pipeline runs unattended once a
# deployment opts in.
#
# Opting in is explicit: the job refuses to run until `archive_directory` is
# set in config/server.yml. That directory must be covered by the server's
# backup regime — the exported files ARE the long-term record once the live
# rows are pruned (see docs/data-retention-strategy.md).
#
# Safety: the marker only advances after the written file has been re-read
# and its row count verified against the database, so PruneOldAudits can
# never delete rows that aren't in a verified archive file. Any failure
# leaves the marker untouched and lands the job in the Resque failed queue.
class ArchiveOldAudits
  @queue = :maintenance

  RETENTION_YEARS = PruneOldAudits::RETENTION_YEARS
  BATCH_SIZE = 5_000

  def self.perform
    directory = Rails.configuration.x.server_config['archive_directory']
    if directory.blank?
      Rails.logger.info 'ArchiveOldAudits: archive_directory is not set in server.yml; ' \
                        'refusing to run. Set it to a backed-up path to enable audit archival.'
      return 0
    end

    lower = JobMetadata.last_run(PruneOldAudits::ARCHIVE_MARKER)
    upper = RETENTION_YEARS.years.ago
    if lower >= upper
      Rails.logger.info "ArchiveOldAudits: nothing to archive (already archived through #{lower.to_date})"
      return 0
    end

    band = Audited::Audit.where(created_at: lower...upper)
    expected = band.count

    if expected.positive?
      path = write_archive_file(directory, band, expected, upper)
      Rails.logger.info "ArchiveOldAudits: archived #{expected} audits created before #{upper.to_date} to #{path}"
    else
      Rails.logger.info "ArchiveOldAudits: no audits in band #{lower.to_date}...#{upper.to_date}; advancing marker"
    end

    JobMetadata.find_or_initialize_by(job_name: PruneOldAudits::ARCHIVE_MARKER)
               .update!(last_run_at: upper)
    expected
  end

  # Writes the band to <directory>/audits_through_<upper>_<run stamp>.ndjson.gz
  # via a .tmp file that is only renamed into place after verification.
  def self.write_archive_file(directory, band, expected, upper)
    FileUtils.mkdir_p(directory)
    filename = "audits_through_#{upper.strftime('%Y-%m-%d')}_#{Time.current.strftime('%Y%m%d%H%M%S')}.ndjson.gz"
    path = File.join(directory, filename)
    tmp_path = "#{path}.tmp"

    written = 0
    Zlib::GzipWriter.open(tmp_path) do |gz|
      band.find_each(batch_size: BATCH_SIZE) do |audit|
        gz.puts(audit.attributes.to_json)
        written += 1
      end
    end

    readable = Zlib::GzipReader.open(tmp_path) { |gz| gz.each_line.count }
    unless written == expected && readable == expected
      raise "ArchiveOldAudits: verification failed for #{tmp_path} " \
            "(expected #{expected}, wrote #{written}, re-read #{readable}); marker not advanced"
    end

    File.rename(tmp_path, path)
    path
  end
end
