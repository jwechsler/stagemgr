require 'rails_helper'

# config.x.rand_clause is set to `1` in the test environment (see
# config/environments/test.rb), so Production.additional_upcoming_scope's
# `order(Rails.configuration.x.rand_clause)` resolves to `ORDER BY 1`, i.e. by
# id/creation order. That makes the walk order in #additional_upcoming_entries
# deterministic for these specs.
RSpec.describe 'Production.additional_upcoming_entries' do
  let(:address) { FactoryBot.create(:address) }
  let(:order) { FactoryBot.create(:ticket_order, address: address) }

  def eligible_production(**attrs)
    FactoryBot.create(:production, {
      status: Production::ACTIVE,
      production_class: Production::PLAY,
      opening_at: Date.today,
      first_preview_at: Date.today,
      closing_at: Time.now.end_of_week + 2.weeks
    }.merge(attrs))
  end

  describe 'active festival collapse' do
    it 'collapses multiple members of an active festival into a single Festival entry, keeping standalone shows' do
      festival = FactoryBot.create(:festival, status: Festival::ACTIVE)
      first_member = eligible_production(festival: festival)
      second_member = eligible_production(festival: festival)
      standalone = eligible_production

      entries = Production.additional_upcoming_entries(order)

      expect(entries).to include(festival)
      expect(entries).to include(standalone)
      expect(entries).not_to include(first_member)
      expect(entries).not_to include(second_member)
      expect(entries.count { |entry| entry.is_a?(Festival) }).to eq(1)
    end
  end

  describe 'inactive festival pass-through' do
    it 'keeps members of an inactive festival as plain productions rather than collapsing them' do
      inactive_festival = FactoryBot.create(:festival, status: Festival::INACTIVE)
      member_one = eligible_production(festival: inactive_festival)
      member_two = eligible_production(festival: inactive_festival)

      entries = Production.additional_upcoming_entries(order)

      expect(entries).to include(member_one, member_two)
      expect(entries).not_to include(inactive_festival)
    end
  end

  describe 'cap of 3' do
    it 'never returns more than 3 entries' do
      4.times { eligible_production }

      entries = Production.additional_upcoming_entries(order)

      expect(entries.size).to eq(3)
    end

    it 'counts a collapsed festival as a single slot toward the cap' do
      festival = FactoryBot.create(:festival, status: Festival::ACTIVE)
      3.times { eligible_production(festival: festival) }
      standalone_one = eligible_production
      standalone_two = eligible_production

      entries = Production.additional_upcoming_entries(order)

      expect(entries.size).to eq(3)
      expect(entries).to include(festival, standalone_one, standalone_two)
    end
  end

  describe 'address exclusion' do
    it 'excludes productions the address already has an order against, same as the legacy lottery' do
      already_seen = eligible_production
      performance = FactoryBot.create(:performance, production: already_seen)
      FactoryBot.create(:ticket_order, address: address, performance: performance)
      other = eligible_production

      entries = Production.additional_upcoming_entries(order)

      expect(entries).not_to include(already_seen)
      expect(entries).to include(other)
    end
  end
end
