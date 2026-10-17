# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'lgl rake tasks' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'lgl:backfill' }
  end

  before { allow(Resque).to receive(:enqueue) }

  %w[lgl:backfill lgl:backfill_now lgl:link_by_email lgl:link_by_email_dry_run
     lgl:replicate lgl:replicate_dry_run].each do |name|
    it "#{name} aborts naming littlegreenlight.sync and LGL_API_KEY when LGL is disabled" do
      allow(LglBackfillLinks).to receive(:perform)
      allow(LglBackfillLinks).to receive(:link_by_email)
      allow(LglBackfillLinks).to receive(:replicate)

      expect { Rake::Task[name].execute }
        .to raise_error(SystemExit).and output(/littlegreenlight\.sync.*LGL_API_KEY/).to_stderr

      expect(Resque).not_to have_received(:enqueue)
      expect(LglBackfillLinks).not_to have_received(:perform)
      expect(LglBackfillLinks).not_to have_received(:link_by_email)
      expect(LglBackfillLinks).not_to have_received(:replicate)
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

  describe 'replicate tasks' do
    def ids(*values)
      Rake::TaskArguments.new([:ids], values)
    end

    before { allow(Lgl).to receive(:enabled?).and_return(true) }

    it 'lgl:replicate_dry_run lists each constituent and the counts inline, for the given ids' do
      allow(LglBackfillLinks).to receive(:replicate).with(constituent_ids: %w[123 456], dry_run: true) do |**_, &block|
        block.call('123', 'Pat Smith', :created, nil)
        block.call('456', 'Lee Jones', :linked, 77)
        { created: 1, linked: 1 }
      end

      expect { Rake::Task['lgl:replicate_dry_run'].execute(ids('123', '456')) }
        .to output(/123\s+Pat Smith\s+created\s*\n456\s+Lee Jones\s+linked\s+\(#77\).*created\s+1\n.*linked\s+1/m).to_stdout

      expect(Resque).not_to have_received(:enqueue)
    end

    it 'lgl:replicate_dry_run covers every constituent without ids' do
      allow(LglBackfillLinks).to receive(:replicate).and_return({})

      expect { Rake::Task['lgl:replicate_dry_run'].execute(ids) }.not_to output.to_stderr

      expect(LglBackfillLinks).to have_received(:replicate).with(constituent_ids: nil, dry_run: true)
    end

    it 'lgl:replicate with ids runs inline and prints the created address ids' do
      allow(LglBackfillLinks).to receive(:replicate).with(constituent_ids: %w[123]) do |**_, &block|
        block.call('123', 'Pat Smith', :created, 501)
        { created: 1 }
      end

      expect { Rake::Task['lgl:replicate'].execute(ids('123')) }.to output(/123\s+created\s+\(#501\)/).to_stdout

      expect(Resque).not_to have_received(:enqueue)
    end

    it 'lgl:replicate without ids queues the replicate mode' do
      allow(LglBackfillLinks).to receive(:replicate)

      expect { Rake::Task['lgl:replicate'].execute(ids) }.to output(/Queued/).to_stdout

      expect(Resque).to have_received(:enqueue).with(LglBackfillLinks, 'replicate')
      expect(LglBackfillLinks).not_to have_received(:replicate)
    end
  end
end
