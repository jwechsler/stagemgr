# frozen_string_literal: true

namespace :lgl do
  desc 'Queue the one-time LGL backfill (local LGL ID tags only; no LGL writes)'
  task backfill: :environment do
    abort 'LGL is not configured (LGL_API_KEY)' unless Lgl.enabled?

    Resque.enqueue(LglBackfillLinks)
    puts 'Queued LglBackfillLinks on the lgl queue'
  end

  desc 'Run the LGL backfill inline and print the counts (local LGL ID tags only; no LGL writes)'
  task backfill_now: :environment do
    abort 'LGL is not configured (LGL_API_KEY)' unless Lgl.enabled?

    counts = LglBackfillLinks.perform
    counts.sort.each { |result, count| puts "#{result.to_s.ljust(20)} #{count}" }
  end
end
