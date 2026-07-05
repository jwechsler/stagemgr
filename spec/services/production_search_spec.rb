require 'rails_helper'

RSpec.describe ProductionSearch do
  let(:theater)       { FactoryBot.create(:theater, name: 'Steppenwolf') }
  let(:other_theater) { FactoryBot.create(:theater, name: 'Goodman') }

  let!(:active_production) do
    FactoryBot.create(:production, theater: theater, name: 'Hamlet', season: 2025)
  end
  let!(:presale_production) do
    FactoryBot.create(:production, theater: theater, name: 'Hamlet Presale', season: 2025,
                                   status: Production::PRESALE)
  end
  let!(:inactive_production) do
    FactoryBot.create(:production, theater: theater, name: 'Hamlet Inactive', season: 2024,
                                   status: Production::INACTIVE)
  end
  let!(:other_production) do
    FactoryBot.create(:production, theater: other_theater, name: 'Hamlet Uptown', season: 2025)
  end

  let(:admin_ability)   { Ability.new(FactoryBot.create(:admin_user)) }
  let(:theater_ability) { Ability.new(FactoryBot.create(:user, theaters: [theater])) }

  def result_names(results)
    results.reject { |r| r[:group_key] }.map { |r| r[:name] }
  end

  describe 'scope whitelist' do
    it 'raises KeyError for an unknown scope' do
      expect { described_class.new(admin_ability, 'evil') }.to raise_error(KeyError)
    end

    it 'excludes presale productions in the analysis scope' do
      names = result_names(described_class.new(admin_ability, 'analysis').search('Hamlet'))
      expect(names).to include('Hamlet', 'Hamlet Inactive')
      expect(names).not_to include('Hamlet Presale')
    end

    it 'includes every accessible production in the reports scope' do
      names = result_names(described_class.new(admin_ability, 'reports').search('Hamlet'))
      expect(names).to include('Hamlet', 'Hamlet Presale', 'Hamlet Inactive')
    end

    it 'excludes inactive productions in the imports scope' do
      names = result_names(described_class.new(admin_ability, 'imports').search('Hamlet'))
      expect(names).to include('Hamlet', 'Hamlet Presale')
      expect(names).not_to include('Hamlet Inactive')
    end
  end

  describe 'ability row scoping' do
    it 'limits theater users to their granted theaters' do
      names = result_names(described_class.new(theater_ability, 'reports').search('Hamlet'))
      expect(names).to include('Hamlet')
      expect(names).not_to include('Hamlet Uptown')
    end

    it 'gives admins productions across all theaters' do
      names = result_names(described_class.new(admin_ability, 'reports').search('Hamlet'))
      expect(names).to include('Hamlet', 'Hamlet Uptown')
    end
  end

  describe '#search' do
    subject(:searcher) { described_class.new(admin_ability, 'reports') }

    it 'mixes season, theater, and tag group entries with productions' do
      TheaterTag.create!(theater: theater, name: 'Storefront 2025')
      results = searcher.search('2025')
      keys = results.filter_map { |r| r[:group_key] }
      expect(keys).to include('season:2025', 'tag:Storefront 2025')
      expect(result_names(results)).to include('Hamlet')
    end

    it 'returns theater group entries for theater-name matches' do
      results = searcher.search('Steppenwolf')
      expect(results.filter_map { |r| r[:group_key] }).to include("theater:#{theater.id}")
      expect(result_names(results)).to include('Hamlet')
    end

    it 'omits group entries when groups are disabled' do
      results = searcher.search('2025', groups: false)
      expect(results.none? { |r| r[:group_key] }).to be(true)
    end

    it 'excludes a production by id' do
      names = result_names(searcher.search('Hamlet', exclude_id: active_production.id))
      expect(names).not_to include('Hamlet')
      expect(names).to include('Hamlet Uptown')
    end

    it 'dedups tag groups case-insensitively' do
      TheaterTag.create!(theater: theater, name: 'Loop')
      TheaterTag.create!(theater: other_theater, name: 'LOOP')
      results = searcher.search('loop')
      tag_keys = results.filter_map { |r| r[:group_key] }.select { |k| k.start_with?('tag:') }
      expect(tag_keys.length).to eq(1)
    end
  end

  describe '#resolve_group' do
    subject(:searcher) { described_class.new(admin_ability, 'reports') }

    it 'resolves a season group' do
      names = searcher.resolve_group('season:2025').map { |r| r[:name] }
      expect(names).to include('Hamlet', 'Hamlet Uptown')
      expect(names).not_to include('Hamlet Inactive')
    end

    it 'resolves a theater group' do
      names = searcher.resolve_group("theater:#{other_theater.id}").map { |r| r[:name] }
      expect(names).to contain_exactly('Hamlet Uptown')
    end

    it 'resolves a tag group case-insensitively' do
      TheaterTag.create!(theater: theater, name: 'Storefront')
      names = searcher.resolve_group('tag:storefront').map { |r| r[:name] }
      expect(names).to include('Hamlet')
      expect(names).not_to include('Hamlet Uptown')
    end

    it 'honors the consumer scope when resolving' do
      names = described_class.new(admin_ability, 'imports').resolve_group('season:2024')
                             .map { |r| r[:name] }
      expect(names).not_to include('Hamlet Inactive')
    end

    it 'honors ability scoping when resolving' do
      names = described_class.new(theater_ability, 'reports').resolve_group('season:2025')
                             .map { |r| r[:name] }
      expect(names).not_to include('Hamlet Uptown')
    end

    it 'returns an empty list for a garbage group key' do
      expect(searcher.resolve_group('bogus')).to eq([])
      expect(searcher.resolve_group('bogus:12')).to eq([])
    end
  end
end
