require 'rails_helper'

RSpec.describe LoggedJob do
  # Named so the recorded job_name is predictable; an anonymous class has none.
  before do
    stub_const('LoggedJobSpecJob', Class.new do
      include LoggedJob

      def self.perform(*_args); end
    end)
  end

  it 'exposes the hook to Resque as a class method on the including job' do
    # The regression this guards: `def self.after_perform` inside the module
    # defined the method on the module, so Resque found no hook at all.
    expect(Resque::Plugin.after_hooks(LoggedJobSpecJob))
      .to include('after_perform_record_last_run')
  end

  it 'records the last run under the including class name' do
    freeze_time do
      LoggedJobSpecJob.after_perform_record_last_run

      expect(JobMetadata.last_run('LoggedJobSpecJob')).to eq(Time.current)
    end
  end

  it 'updates the existing row rather than adding a second one' do
    LoggedJobSpecJob.after_perform_record_last_run
    LoggedJobSpecJob.after_perform_record_last_run

    expect(JobMetadata.where(job_name: 'LoggedJobSpecJob').count).to eq(1)
  end

  it 'accepts the arguments perform was called with' do
    expect { LoggedJobSpecJob.after_perform_record_last_run(1, 'two') }
      .to change { JobMetadata.where(job_name: 'LoggedJobSpecJob').count }.by(1)
  end

  it 'logs and swallows a write failure so a finished job is not failed' do
    allow(JobMetadata).to receive(:record_last_run)
      .and_raise(ActiveRecord::RecordInvalid.new(JobMetadata.new))
    expect(Rails.logger).to receive(:error).with(/LoggedJobSpecJob/)

    expect { LoggedJobSpecJob.after_perform_record_last_run }.not_to raise_error
  end
end
