require 'rails_helper'

RSpec.describe PruneOldAudits do
  let(:order) { FactoryBot.create(:ticket_order) }

  def create_audit(age:)
    audit = Audited::Audit.create!(auditable: order, action: 'update', audited_changes: { 'status' => %w[New Processed] })
    audit.update_column(:created_at, age.ago)
    audit
  end

  def record_archive_marker(archived_through)
    JobMetadata.create!(job_name: described_class::ARCHIVE_MARKER, last_run_at: archived_through)
  end

  before { allow(described_class).to receive(:sleep) }

  context 'without an archive marker' do
    it 'refuses to delete anything' do
      stale = create_audit(age: 4.years)

      expect(described_class.perform).to eq(0)

      expect(Audited::Audit.exists?(stale.id)).to be true
    end
  end

  context 'with an archive marker covering the retention cutoff' do
    before { record_archive_marker(Time.current) }

    it 'deletes audits older than the retention window' do
      stale = create_audit(age: (described_class::RETENTION_YEARS + 1).years)

      expect(described_class.perform).to be >= 1

      expect(Audited::Audit.exists?(stale.id)).to be false
    end

    it 'preserves audits newer than the retention window' do
      fresh = create_audit(age: 1.year)

      described_class.perform

      expect(Audited::Audit.exists?(fresh.id)).to be true
    end

    it 'works through multiple batches until done' do
      stub_const('PruneOldAudits::BATCH_SIZE', 2)
      stale = Array.new(5) { create_audit(age: 4.years) }

      expect(described_class.perform).to be >= 5

      stale.each { |audit| expect(Audited::Audit.exists?(audit.id)).to be false }
    end
  end

  context 'with an archive marker older than the retention cutoff' do
    it 'only deletes audits already covered by the archive' do
      record_archive_marker(42.months.ago)
      archived = create_audit(age: 48.months)
      unarchived = create_audit(age: 39.months)

      described_class.perform

      expect(Audited::Audit.exists?(archived.id)).to be false
      expect(Audited::Audit.exists?(unarchived.id)).to be true
    end
  end
end
