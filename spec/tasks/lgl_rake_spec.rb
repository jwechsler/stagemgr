# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'lgl rake tasks' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'lgl:backfill' }
  end

  before { allow(Resque).to receive(:enqueue) }

  %w[lgl:backfill lgl:backfill_now].each do |name|
    it "#{name} aborts naming littlegreenlight.sync and LGL_API_KEY when LGL is disabled" do
      allow(LglBackfillLinks).to receive(:perform)

      expect { Rake::Task[name].execute }
        .to raise_error(SystemExit).and output(/littlegreenlight\.sync.*LGL_API_KEY/).to_stderr

      expect(Resque).not_to have_received(:enqueue)
      expect(LglBackfillLinks).not_to have_received(:perform)
    end
  end

  it 'lgl:backfill queues the job when LGL is enabled' do
    allow(Lgl).to receive(:enabled?).and_return(true)

    expect { Rake::Task['lgl:backfill'].execute }.to output(/Queued/).to_stdout

    expect(Resque).to have_received(:enqueue).with(LglBackfillLinks)
  end
end
