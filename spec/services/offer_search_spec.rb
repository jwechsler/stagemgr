require 'rails_helper'

RSpec.describe OfferSearch do
  let(:theater)       { FactoryBot.create(:theater, name: 'Steppenwolf') }
  let(:other_theater) { FactoryBot.create(:theater, name: 'Goodman') }

  let(:admin_ability)   { Ability.new(FactoryBot.create(:admin_user)) }
  let(:theater_ability) { Ability.new(FactoryBot.create(:user, theaters: [theater])) }

  def result_names(results)
    results.reject { |r| r[:group_key] }.map { |r| r[:name] }
  end

  def group_keys(results)
    results.filter_map { |r| r[:group_key] }
  end

  describe 'kind whitelist' do
    it 'raises KeyError for an unknown kind' do
      expect { described_class.new(admin_ability, 'evil') }.to raise_error(KeyError)
    end
  end

  describe 'membership offers' do
    subject(:searcher) { described_class.new(admin_ability, 'membership') }

    let!(:active_offer)   { FactoryBot.create(:membership_offer, name: 'Gold Membership') }
    let!(:inactive_offer) do
      FactoryBot.create(:membership_offer, name: 'Gold Legacy', status: MembershipOffer::INACTIVE)
    end

    it 'finds active offers by name and excludes inactive ones' do
      names = result_names(searcher.search('Gold'))
      expect(names).to include('Gold Membership')
      expect(names).not_to include('Gold Legacy')
    end

    it 'offers tag groups and resolves them to active offers only' do
      active_offer.membership_offer_tags.create!(name: 'Premium')
      inactive_offer.membership_offer_tags.create!(name: 'Premium')

      results = searcher.search('prem')
      expect(group_keys(results)).to include('tag:Premium')

      names = searcher.resolve_group('tag:premium').pluck(:name)
      expect(names).to contain_exactly('Gold Membership')
    end

    it 'dedups tag groups case-insensitively' do
      active_offer.membership_offer_tags.create!(name: 'Loop')
      FactoryBot.create(:membership_offer, name: 'Silver').membership_offer_tags.create!(name: 'LOOP')

      tag_keys = group_keys(searcher.search('loop')).select { |k| k.start_with?('tag:') }
      expect(tag_keys.length).to eq(1)
    end

    it 'never offers theater groups' do
      expect(group_keys(searcher.search('Steppenwolf'))).to be_empty
      expect(searcher.resolve_group("theater:#{theater.id}")).to eq([])
    end
  end

  describe 'flex pass offers' do
    subject(:searcher) { described_class.new(admin_ability, 'flex_pass') }

    let!(:restricted_offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Wit Pass', theater: theater)
    end
    let!(:excluding_offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Roving Pass', theater: theater, exclude_theater: true)
    end
    let!(:unrestricted_offer) { FactoryBot.create(:flex_pass_offer, name: 'Anywhere Pass') }
    let!(:inactive_offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Wit Retired', theater: theater, active: false,
                                          on_sale_to_public: false)
    end

    it 'finds active offers by name and excludes inactive ones' do
      names = result_names(searcher.search('Wit'))
      expect(names).to include('Wit Pass')
      expect(names).not_to include('Wit Retired')
    end

    it 'matches offers by their theater name' do
      names = result_names(searcher.search('Steppenwolf'))
      expect(names).to include('Wit Pass', 'Roving Pass')
      expect(names).not_to include('Anywhere Pass')
    end

    it 'labels offers with their restriction' do
      labels = searcher.search('Pass').reject { |r| r[:group_key] }.pluck(:label)
      expect(labels).to include('Wit Pass — Only Steppenwolf', 'Roving Pass — All but Steppenwolf',
                                'Anywhere Pass')
    end

    it 'offers theater groups only for theaters with restricted offers' do
      keys = group_keys(searcher.search('Steppenwolf'))
      expect(keys).to include("theater:#{theater.id}")

      expect(group_keys(searcher.search('Goodman'))).to be_empty
    end

    it 'resolves a theater group without exclude_theater or inactive offers' do
      names = searcher.resolve_group("theater:#{theater.id}").pluck(:name)
      expect(names).to contain_exactly('Wit Pass')
    end

    it 'offers and resolves tag groups' do
      restricted_offer.flex_pass_offer_tags.create!(name: 'Holiday')
      unrestricted_offer.flex_pass_offer_tags.create!(name: 'holiday')

      expect(group_keys(searcher.search('holi'))).to include('tag:Holiday')
      names = searcher.resolve_group('tag:HOLIDAY').pluck(:name)
      expect(names).to contain_exactly('Wit Pass', 'Anywhere Pass')
    end

    it 'limits theater users to their granted theaters (public offers stay visible)' do
      private_elsewhere = FactoryBot.create(:flex_pass_offer, name: 'Private Pass',
                                                              theater: other_theater, on_sale_to_public: false)
      names = result_names(described_class.new(theater_ability, 'flex_pass').search('Pass'))
      expect(names).to include('Wit Pass', 'Anywhere Pass') # Anywhere Pass is on public sale
      expect(names).not_to include(private_elsewhere.name)
    end

    it 'returns an empty list for a garbage group key' do
      expect(searcher.resolve_group('bogus')).to eq([])
      expect(searcher.resolve_group('bogus:12')).to eq([])
    end
  end

  describe '#permitted_ids' do
    subject(:searcher) { described_class.new(admin_ability, 'flex_pass') }

    let!(:active_offer)   { FactoryBot.create(:flex_pass_offer, name: 'Wit Pass') }
    let!(:inactive_offer) do
      FactoryBot.create(:flex_pass_offer, name: 'Retired', active: false, on_sale_to_public: false)
    end

    it 'keeps authorized active ids and drops everything else' do
      ids = searcher.permitted_ids([active_offer.id.to_s, inactive_offer.id, 0, 'junk', 999_999])
      expect(ids).to contain_exactly(active_offer.id)
    end

    it 'drops ids outside a theater user ability' do
      mine = FactoryBot.create(:flex_pass_offer, name: 'Mine', theater: theater)
      foreign = FactoryBot.create(:flex_pass_offer, name: 'Foreign', theater: other_theater,
                                                    on_sale_to_public: false)
      ids = described_class.new(theater_ability, 'flex_pass')
                           .permitted_ids([mine.id, foreign.id])
      expect(ids).to contain_exactly(mine.id)
    end

    it 'returns an empty array for blank input' do
      expect(searcher.permitted_ids(nil)).to eq([])
      expect(searcher.permitted_ids([])).to eq([])
    end
  end
end
