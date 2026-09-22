require 'rails_helper'

RSpec.describe JobMetadata do
  let(:job_name) { 'SpecJob' }

  describe '.record_run_at' do
    it 'creates the row when the job has no watermark yet' do
      described_class.record_run_at(job_name, 3.days.ago)

      # last_run_at is DATETIME(0), so stored values lose sub-second precision.
      expect(described_class.last_run(job_name)).to be_within(1.second).of(3.days.ago)
    end

    it 'updates in place rather than adding a second row' do
      described_class.record_run_at(job_name, 3.days.ago)
      described_class.record_run_at(job_name, 1.day.ago)

      expect(described_class.where(job_name: job_name).count).to eq(1)
      expect(described_class.last_run(job_name)).to be_within(1.second).of(1.day.ago)
    end

    it 'leaves created_at alone when updating' do
      described_class.record_run_at(job_name, 3.days.ago)
      created_at = described_class.find_by(job_name: job_name).created_at

      described_class.record_run_at(job_name, 1.day.ago)

      expect(described_class.find_by(job_name: job_name).created_at)
        .to be_within(1.second).of(created_at)
    end

    it 'records an explicit watermark, not the current time' do
      freeze_time do
        described_class.record_run_at(job_name, 10.days.ago)

        expect(described_class.last_run(job_name)).not_to be_within(1.minute).of(Time.current)
      end
    end

    it 'resolves a concurrent insert instead of duplicating the row' do
      # What the unique index on job_name buys: the losing writer's INSERT
      # becomes an update rather than a second row that last_run may then read.
      described_class.connection.execute(
        described_class.sanitize_sql_array(
          [described_class::UPSERT_SQL, job_name, 5.days.ago, Time.current, Time.current]
        )
      )
      described_class.record_run_at(job_name, 1.day.ago)

      expect(described_class.where(job_name: job_name).count).to eq(1)
    end

    it 'refuses a duplicate row at the database level' do
      described_class.record_run_at(job_name, 3.days.ago)

      duplicate = described_class.sanitize_sql_array(
        ['INSERT INTO job_metadata (job_name, last_run_at, created_at, updated_at) ' \
         'VALUES (?, NOW(), NOW(), NOW())', job_name]
      )

      expect { described_class.connection.execute(duplicate) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.record_last_run' do
    it 'records the current time' do
      freeze_time do
        described_class.record_last_run(job_name)

        expect(described_class.last_run(job_name)).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '.last_run' do
    it 'returns the epoch when the job has never run' do
      expect(described_class.last_run('NeverRun')).to eq(Time.at(0))
    end
  end
end
