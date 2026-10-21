# The implementation lives in lib/tasks/addresses/ (ignored by the Zeitwerk
# autoloader, hence require_relative) so it can be unit tested.
require_relative 'addresses/name_reparser'

namespace :addresses do
  desc 'Re-derive first/middle/last name and last_first_name from full_name ' \
       '(splits middle names out of first_name, keeps stored middle names; DRY_RUN=1 to preview)'
  task reparse_names: :environment do
    # LEGACY backfill: see Addresses::NameReparser. Idempotent -- a row
    # already in the parsed shape is counted as unchanged and not written.
    dry_run = ENV['DRY_RUN'].present?
    puts "addresses:reparse_names#{' (DRY_RUN)' if dry_run}"

    summary = Addresses::NameReparser.new(dry_run: dry_run).call

    if dry_run
      summary.samples.each { |line| puts "  #{line}" }
      puts "  ... (first #{summary.samples.size} shown)" if summary.changed > summary.samples.size
    end
    verb = dry_run ? 'would change' : 'changed'
    puts "Done. #{summary.scanned} scanned, #{summary.changed} #{verb}, #{summary.unchanged} unchanged."
  end
end
