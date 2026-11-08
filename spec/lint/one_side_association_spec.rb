# frozen_string_literal: true

require 'rails_helper'

# Guards the one-side association rule (docs/rails-upgrade-plan.md, Release 2
# defaults flips): never name the owner (`order: o`) AND append the same record
# to the owner's collection (`o.payments <<`). With has_many_inversing a record
# built with `order: o` is already in `o.payments`, and on Rails 6.1 the append
# then adds the same object twice. Preferred form:
# `o.payments << FactoryBot.build(:x, ...)` with no `order:`. `create(order: o)`
# alone is fine where no in-memory read of the collection follows.
RSpec.describe 'one-side association writes' do
  collections = 'payments|service_line_items|adjustment_line_items|donation_line_items|tasks'
  append_pattern = /\.(?:#{collections})\s*(?:<<|\.concat)/
  owner_pattern = /\border: /
  context_lines = 4
  root = File.expand_path('../..', __dir__)

  define_method(:offending_sites) do
    Dir.glob(File.join(root, '{spec,features,app,lib}/**/*.rb')).flat_map do |path|
      next [] if path == __FILE__

      lines = File.readlines(path)
      lines.each_index.filter_map do |i|
        # build + << is the correct form while the owner is still unsaved (before(:create) blocks)
        next unless lines[i].match?(append_pattern) && lines[i].exclude?('FactoryBot.build(')

        window = lines[i, context_lines + 1].join
        "#{path.delete_prefix("#{root}/")}:#{i + 1}" if window.match?(owner_pattern)
      end
    end
  end

  it 'never both names the owner via order: and appends the record to the owner collection' do
    sites = offending_sites
    message = "Found #{sites.size} one-side association write(s):\n  #{sites.join("\n  ")}\n" \
              "Use `o.payments << FactoryBot.build(:x, ...)` WITHOUT `order:` (preferred), or " \
              'create(order: o) alone, but never both. ' \
              'See docs/rails-upgrade-plan.md (Release 2 defaults flips).'
    expect(sites).to be_empty, message
  end
end
