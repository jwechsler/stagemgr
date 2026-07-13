require 'rails_helper'

RSpec.describe ArchiveOldAudits do
  let(:order) { FactoryBot.create(:ticket_order) }
  let(:archive_dir) { Dir.mktmpdir('stagemgr-archive') }

  after { FileUtils.remove_entry(archive_dir) if File.directory?(archive_dir) }

  def configure_archive_directory(value)
    config = Rails.configuration.x.server_config.merge('archive_directory' => value)
    allow(Rails.configuration.x).to receive(:server_config).and_return(config)
  end

  def create_audit(age:)
    audit = Audited::Audit.create!(auditable: order, action: 'update', audited_changes: { 'status' => %w[New Processed] })
    audit.update_column(:created_at, age.ago)
    audit
  end

  def marker_time
    JobMetadata.last_run(PruneOldAudits::ARCHIVE_MARKER)
  end

  def archive_files
    Dir[File.join(archive_dir, 'audits_through_*.ndjson.gz')]
  end

  context 'when archive_directory is blank' do
    it 'refuses to run and does not advance the marker' do
      configure_archive_directory(nil)
      create_audit(age: 4.years)

      expect(described_class.perform).to eq(0)

      expect(marker_time).to eq(Time.at(0))
    end
  end

  context 'when archive_directory is configured' do
    before { configure_archive_directory(archive_dir) }

    it 'writes aged audits to a gzipped NDJSON file and advances the marker' do
      stale = create_audit(age: 4.years)
      fresh = create_audit(age: 1.year)

      expect(described_class.perform).to eq(1)

      expect(archive_files.size).to eq(1)
      lines = Zlib::GzipReader.open(archive_files.first) { |gz| gz.each_line.map { |l| JSON.parse(l) } }
      expect(lines.map { |row| row['id'] }).to eq([stale.id])
      expect(marker_time).to be_within(1.minute).of(described_class::RETENTION_YEARS.years.ago)
      expect(Audited::Audit.exists?(fresh.id)).to be true
    end

    it 'only archives audits newer than the existing marker' do
      JobMetadata.create!(job_name: PruneOldAudits::ARCHIVE_MARKER, last_run_at: 42.months.ago)
      already_archived = create_audit(age: 48.months)
      unarchived = create_audit(age: 39.months)

      expect(described_class.perform).to eq(1)

      lines = Zlib::GzipReader.open(archive_files.first) { |gz| gz.each_line.map { |l| JSON.parse(l) } }
      expect(lines.map { |row| row['id'] }).to eq([unarchived.id])
      expect(lines.map { |row| row['id'] }).not_to include(already_archived.id)
    end

    it 'advances the marker without writing a file when the band is empty' do
      create_audit(age: 1.year)

      expect(described_class.perform).to eq(0)

      expect(archive_files).to be_empty
      expect(marker_time).to be_within(1.minute).of(described_class::RETENTION_YEARS.years.ago)
    end

    it 'does not advance the marker when the archive file fails verification' do
      create_audit(age: 4.years)
      allow(Zlib::GzipReader).to receive(:open).and_return(0)

      expect { described_class.perform }.to raise_error(/verification failed/)

      expect(marker_time).to eq(Time.at(0))
      expect(archive_files).to be_empty
    end

    it 'leaves audits in place for PruneOldAudits to delete afterwards' do
      stale = create_audit(age: 4.years)

      described_class.perform
      expect(Audited::Audit.exists?(stale.id)).to be true

      allow(PruneOldAudits).to receive(:sleep)
      PruneOldAudits.perform
      expect(Audited::Audit.exists?(stale.id)).to be false
    end
  end
end
