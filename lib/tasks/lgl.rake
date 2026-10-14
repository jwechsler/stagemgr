# frozen_string_literal: true

namespace :lgl do
  desc 'Queue the one-time LGL backfill (local LGL ID tags only; no LGL writes)'
  task backfill: :environment do
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    Resque.enqueue(LglBackfillLinks)
    puts 'Queued LglBackfillLinks on the maintenance queue'
  end

  desc 'Run the LGL backfill inline and print the counts (local LGL ID tags only; no LGL writes)'
  task backfill_now: :environment do
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    counts = LglBackfillLinks.perform
    counts.sort.each { |result, count| puts "#{result.to_s.ljust(20)} #{count}" }
  end

  desc 'Queue the one-time LGL link by email (writes External Constituent IDs only; run the dry run first)'
  task link_by_email: :environment do
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    Resque.enqueue(LglBackfillLinks, LglBackfillLinks::LINK_BY_EMAIL_MODE)
    puts 'Queued LglBackfillLinks (link_by_email) on the maintenance queue'
  end

  desc 'Count what lgl:link_by_email would link, inline; enqueues and writes nothing'
  task link_by_email_dry_run: :environment do
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    counts = LglBackfillLinks.link_by_email(dry_run: true)
    counts.sort.each { |(kind, outcome), count| puts "#{kind.to_s.ljust(20)} #{outcome.to_s.ljust(16)} #{count}" }
  end

  # LGL constituent ids from the task arguments: rake "lgl:replicate[123,456]"
  # passes each comma-separated id as its own argument. nil means all.
  lgl_constituent_ids = ->(args) { args.to_a.map { |id| id.to_s.strip }.reject(&:empty?).presence }

  desc 'List what lgl:replicate would do per unlinked LGL constituent, inline; writes nothing. ' \
       'Optional ids: rake "lgl:replicate_dry_run[123,456]"'
  task :replicate_dry_run, [:ids] => :environment do |_task, args|
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    counts = LglBackfillLinks.replicate(constituent_ids: lgl_constituent_ids.call(args), dry_run: true) do |lgl_id, name, outcome, address_id|
      puts "#{lgl_id.ljust(10)} #{name.ljust(30)} #{outcome.to_s.ljust(16)} #{"(##{address_id})" if address_id}"
    end
    counts.sort.each { |outcome, count| puts "#{outcome.to_s.ljust(20)} #{count}" }
  end

  desc 'Link or create Stagemgr customers for unlinked LGL constituents (run the dry run first). ' \
       'With ids, inline: rake "lgl:replicate[123,456]"; without, queued'
  task :replicate, [:ids] => :environment do |_task, args|
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    ids = lgl_constituent_ids.call(args)
    if ids.nil?
      Resque.enqueue(LglBackfillLinks, LglBackfillLinks::REPLICATE_MODE)
      next puts 'Queued LglBackfillLinks (replicate) on the maintenance queue'
    end

    counts = LglBackfillLinks.replicate(constituent_ids: ids) do |lgl_id, _name, outcome, address_id|
      puts "#{lgl_id.ljust(10)} #{outcome.to_s.ljust(16)} #{"(##{address_id})" if address_id}"
    end
    counts.sort.each { |outcome, count| puts "#{outcome.to_s.ljust(20)} #{count}" }
  end
end
