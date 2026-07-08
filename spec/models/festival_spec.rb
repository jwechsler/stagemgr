require 'rails_helper'

RSpec.describe Festival, type: :model do
  describe 'validations' do
    it 'requires a name' do
      expect(FactoryBot.build(:festival, name: nil)).not_to be_valid
    end

    it 'requires a known status' do
      expect(FactoryBot.build(:festival, status: 'Bogus')).not_to be_valid
    end

    it 'defaults the slug from the name' do
      festival = FactoryBot.create(:festival, name: 'Physical Theatre Festival')
      expect(festival.slug).to eq('physical-theatre-festival')
    end

    it 'rejects malformed slugs' do
      expect(FactoryBot.build(:festival, slug: 'Bad Slug!')).not_to be_valid
    end

    it 'requires unique slugs' do
      FactoryBot.create(:festival, slug: 'fringe')
      expect(FactoryBot.build(:festival, slug: 'fringe')).not_to be_valid
    end

    it 'requires a slug when the landing page is enabled' do
      festival = FactoryBot.build(:festival, :with_landing_page, name: '')
      festival.slug = ''
      expect(festival).not_to be_valid
    end
  end

  describe '#date_range' do
    it 'prefers stored dates' do
      festival = FactoryBot.create(:festival, starts_on: Date.new(2026, 6, 4), ends_on: Date.new(2026, 6, 28))
      expect(festival.date_range).to eq([Date.new(2026, 6, 4), Date.new(2026, 6, 28)])
    end

    it 'falls back to dates derived from member productions' do
      festival = FactoryBot.create(:festival, starts_on: nil, ends_on: nil)
      FactoryBot.create(:production, festival: festival,
                                     first_preview_at: Date.today + 1.week,
                                     closing_at: Date.today + 3.weeks)
      FactoryBot.create(:production, festival: festival,
                                     first_preview_at: Date.today + 2.weeks,
                                     closing_at: Date.today + 5.weeks)

      expect(festival.date_range).to eq([Date.today + 1.week, Date.today + 5.weeks])
    end

    it 'returns nils for an empty festival with no stored dates' do
      festival = FactoryBot.create(:festival, starts_on: nil, ends_on: nil)
      expect(festival.date_range).to eq([nil, nil])
    end
  end

  describe '#public_productions' do
    it 'only includes visible, publicly sellable member productions' do
      festival = FactoryBot.create(:festival)
      member = FactoryBot.create(:production, festival: festival)
      FactoryBot.create(:production, festival: festival, status: Production::INACTIVE)
      FactoryBot.create(:production) # non-member

      expect(festival.public_productions).to contain_exactly(member)
    end
  end

  describe '#featured_productions' do
    it 'returns members ordered by soonest upcoming performance' do
      festival = FactoryBot.create(:festival)
      later = FactoryBot.create(:production, festival: festival, closing_at: Date.today + 4.weeks)
      sooner = FactoryBot.create(:production, festival: festival, closing_at: Date.today + 4.weeks)
      FactoryBot.create(:performance, production: later, performance_date: Date.today + 10.days)
      FactoryBot.create(:performance, production: sooner, performance_date: Date.today + 2.days)

      expect(festival.featured_productions(2).to_a).to eq([sooner, later])
    end

    it 'excludes members with only past performances' do
      festival = FactoryBot.create(:festival)
      stale = FactoryBot.create(:production, festival: festival)
      FactoryBot.create(:performance, production: stale, performance_date: Date.today - 2.days)

      expect(festival.featured_productions).to be_empty
    end
  end

  describe '#theaters' do
    it 'derives the distinct theaters from member productions' do
      festival = FactoryBot.create(:festival)
      theater_one = FactoryBot.create(:theater)
      theater_two = FactoryBot.create(:theater)
      FactoryBot.create(:production, festival: festival, theater: theater_one)
      FactoryBot.create(:production, festival: festival, theater: theater_one)
      FactoryBot.create(:production, festival: festival, theater: theater_two)

      expect(festival.theaters).to contain_exactly(theater_one, theater_two)
    end
  end

  describe '#to_param' do
    it 'uses the slug when present' do
      expect(FactoryBot.create(:festival, slug: 'fringe-2026').to_param).to eq('fringe-2026')
    end
  end
end
