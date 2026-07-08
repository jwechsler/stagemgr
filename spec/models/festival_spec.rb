require 'rails_helper'

RSpec.describe Festival, type: :model do
  describe 'validations' do
    it 'requires a name' do
      expect(FactoryBot.build(:festival, name: nil)).not_to be_valid
    end

    it 'requires a known status' do
      expect(FactoryBot.build(:festival, status: 'Bogus')).not_to be_valid
    end

    it 'defaults the URL name from the name' do
      festival = FactoryBot.create(:festival, name: 'Physical Theatre Festival')
      expect(festival.url_name).to eq('physical-theatre-festival')
    end

    it 'rejects malformed URL names' do
      expect(FactoryBot.build(:festival, url_name: 'Bad Name!')).not_to be_valid
    end

    it 'requires unique URL names' do
      FactoryBot.create(:festival, url_name: 'fringe')
      expect(FactoryBot.build(:festival, url_name: 'fringe')).not_to be_valid
    end

    it 'requires a URL name when the landing page is enabled' do
      festival = FactoryBot.build(:festival, :with_landing_page, name: '')
      festival.url_name = ''
      expect(festival).not_to be_valid
    end
  end

  describe '#date_range' do
    it 'derives the range from member productions' do
      festival = FactoryBot.create(:festival)
      FactoryBot.create(:production, festival: festival,
                                     first_preview_at: Date.today + 1.week,
                                     closing_at: Date.today + 3.weeks)
      FactoryBot.create(:production, festival: festival,
                                     first_preview_at: Date.today + 2.weeks,
                                     closing_at: Date.today + 5.weeks)

      expect(festival.date_range).to eq([Date.today + 1.week, Date.today + 5.weeks])
    end

    it 'returns nils for a festival with no member productions' do
      festival = FactoryBot.create(:festival)
      expect(festival.date_range).to eq([nil, nil])
    end
  end

  describe '#formatted_date_range' do
    def festival_running(from, to)
      FactoryBot.create(:festival).tap do |festival|
        FactoryBot.create(:production, festival: festival, first_preview_at: from, closing_at: to)
      end
    end

    it 'shows the year once when the range stays within one year' do
      festival = festival_running(Date.new(2026, 7, 8), Date.new(2026, 7, 15))
      expect(festival.formatted_date_range).to eq('July 8 – July 15, 2026')
    end

    it 'shows both years when the range crosses a year boundary' do
      festival = festival_running(Date.new(2026, 12, 28), Date.new(2027, 1, 3))
      expect(festival.formatted_date_range).to eq('December 28, 2026 – January 3, 2027')
    end

    it 'collapses a single-day festival to one date' do
      festival = festival_running(Date.new(2026, 7, 8), Date.new(2026, 7, 8))
      expect(festival.formatted_date_range).to eq('July 8, 2026')
    end

    it 'is nil without member productions' do
      expect(FactoryBot.create(:festival).formatted_date_range).to be_nil
    end
  end

  describe '#upcoming_productions' do
    it 'includes visible members that have not closed and excludes the rest' do
      festival = FactoryBot.create(:festival)
      upcoming = FactoryBot.create(:production, festival: festival, closing_at: Date.today + 1.week)
      FactoryBot.create(:production, festival: festival, closing_at: Date.today - 1.day)
      FactoryBot.create(:production, festival: festival, status: Production::INACTIVE)

      expect(festival.upcoming_productions).to contain_exactly(upcoming)
    end
  end

  describe 'Production#festival_grouped?' do
    it 'is true while an active festival has multiple upcoming shows' do
      festival = FactoryBot.create(:festival)
      member = FactoryBot.create(:production, festival: festival, closing_at: Date.today + 1.week)
      FactoryBot.create(:production, festival: festival, closing_at: Date.today + 2.weeks)

      expect(member.festival_grouped?).to be true
    end

    it 'is false for a festival lone remaining show' do
      festival = FactoryBot.create(:festival)
      member = FactoryBot.create(:production, festival: festival, closing_at: Date.today + 1.week)
      FactoryBot.create(:production, festival: festival, closing_at: Date.today - 1.day)

      expect(member.festival_grouped?).to be false
    end

    it 'is false for inactive festivals and non-members' do
      inactive = FactoryBot.create(:festival, :inactive)
      member = FactoryBot.create(:production, festival: inactive)
      loose = FactoryBot.create(:production)

      expect(member.festival_grouped?).to be false
      expect(loose.festival_grouped?).to be false
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
end
