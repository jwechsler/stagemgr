# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'lgl rake tasks' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'lgl:backfill' }
  end

  before { allow(Resque).to receive(:enqueue) }

  %w[lgl:backfill lgl:backfill_now lgl:link_by_email lgl:link_by_email_dry_run].each do |name|
    it "#{name} aborts naming littlegreenlight.sync and LGL_API_KEY when LGL is disabled" do
      allow(LglBackfillLinks).to receive(:perform)
      allow(LglBackfillLinks).to receive(:link_by_email)

      expect { Rake::Task[name].execute }
        .to raise_error(SystemExit).and output(/littlegreenlight\.sync.*LGL_API_KEY/).to_stderr

      expect(Resque).not_to have_received(:enqueue)
      expect(LglBackfillLinks).not_to have_received(:perform)
      expect(LglBackfillLinks).not_to have_received(:link_by_email)
    end
  end

  it 'lgl:backfill queues the job when LGL is enabled' do
    allow(Lgl).to receive(:enabled?).and_return(true)

    expect { Rake::Task['lgl:backfill'].execute }.to output(/Queued/).to_stdout

    expect(Resque).to have_received(:enqueue).with(LglBackfillLinks)
  end

  it 'lgl:link_by_email queues the link_by_email mode when LGL is enabled' do
    allow(Lgl).to receive(:enabled?).and_return(true)

    expect { Rake::Task['lgl:link_by_email'].execute }.to output(/Queued/).to_stdout

    expect(Resque).to have_received(:enqueue).with(LglBackfillLinks, 'link_by_email')
  end

  it 'lgl:link_by_email_dry_run counts inline without enqueuing' do
    allow(Lgl).to receive(:enabled?).and_return(true)
    allow(LglBackfillLinks).to receive(:link_by_email).with(dry_run: true)
                                                      .and_return({ %i[blank_external_id one_match] => 3 })

    expect { Rake::Task['lgl:link_by_email_dry_run'].execute }
      .to output(/blank_external_id\s+one_match\s+3/).to_stdout

    expect(Resque).not_to have_received(:enqueue)
  end
end
