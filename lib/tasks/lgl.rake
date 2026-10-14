# frozen_string_literal: true

namespace :lgl do
  desc 'Queue the one-time LGL backfill (local LGL ID tags only; no LGL writes)'
  task backfill: :environment do
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    Resque.enqueue(LglBackfillLinks)
    puts 'Queued LglBackfillLinks on the lgl queue'
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
    puts 'Queued LglBackfillLinks (link_by_email) on the lgl queue'
  end

  desc 'Count what lgl:link_by_email would link, inline; enqueues and writes nothing'
  task link_by_email_dry_run: :environment do
    abort Lgl::DISABLED_MESSAGE unless Lgl.enabled?

    counts = LglBackfillLinks.link_by_email(dry_run: true)
    counts.sort.each { |(kind, outcome), count| puts "#{kind.to_s.ljust(20)} #{outcome.to_s.ljust(16)} #{count}" }
  end
end
