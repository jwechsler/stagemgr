require 'rails_helper'

RSpec.describe ProductionsController, type: :controller do
  # A now-playing, publicly visible Primetime production at the given venue.
  def now_playing_play(venue, festival: nil)
    FactoryBot.create(:production,
                      venue: venue,
                      status: Production::ACTIVE,
                      production_class: Production::PLAY,
                      first_preview_at: Date.today,
                      opening_at: Date.today,
                      press_opening_at: Date.today,
                      closing_at: Date.today + 1.week,
                      festival: festival)
  end

  # A Primetime production opening next week (Coming Soon window).
  def coming_soon_play(venue, festival: nil)
    open = Date.today.end_of_week + 1.week
    FactoryBot.create(:production,
                      venue: venue,
                      status: Production::ACTIVE,
                      production_class: Production::PLAY,
                      first_preview_at: open,
                      opening_at: open,
                      press_opening_at: open,
                      closing_at: open + 2.weeks,
                      festival: festival)
  end

  # A Primetime production opening far enough out for Later This Season.
  def long_term_play(venue, festival: nil)
    open = Date.today.end_of_week + 5.months
    FactoryBot.create(:production,
                      venue: venue,
                      status: Production::ACTIVE,
                      production_class: Production::PLAY,
                      first_preview_at: open,
                      opening_at: open,
                      press_opening_at: open,
                      closing_at: open + 2.weeks,
                      festival: festival)
  end

  describe 'GET #box_office' do
    let(:venue) { FactoryBot.create(:venue) }
    let(:festival) { FactoryBot.create(:festival) }

    it 'collapses active-festival members into a single FestivalBand in Now Playing' do
      member_a = now_playing_play(venue, festival: festival)
      member_b = now_playing_play(venue, festival: festival)
      loose = now_playing_play(venue)

      get :box_office

      entries = assigns(:now_playing)
      bands = entries.grep(ProductionsController::FestivalBand)
      expect(bands.size).to eq(1)
      expect(bands.first.festival).to eq(festival)
      expect(bands.first.productions).to match_array([member_a, member_b])

      loose_entries = entries.grep(Production)
      expect(loose_entries).to include(loose)
    end

    it 'never renders banded festival members as loose Production cards' do
      member_a = now_playing_play(venue, festival: festival)
      member_b = now_playing_play(venue, festival: festival)
      now_playing_play(venue)

      get :box_office

      loose_entries = assigns(:now_playing).grep(Production)
      expect(loose_entries).not_to include(member_a, member_b)
    end

    it 'shows the callout only once, in the earliest section, with all upcoming member shows' do
      playing_member = now_playing_play(venue, festival: festival)
      soon_member = coming_soon_play(venue, festival: festival)
      later_member = long_term_play(venue, festival: festival)

      get :box_office

      bands = assigns(:now_playing).grep(ProductionsController::FestivalBand)
      expect(bands.size).to eq(1)
      expect(bands.first.productions).to match_array([playing_member, soon_member, later_member])

      expect(assigns(:coming_soon)).to be_empty
      expect(assigns(:long_term)).to be_empty
    end

    it 'renders a lone upcoming festival show as a plain production card' do
      only_member = now_playing_play(venue, festival: festival)

      get :box_office

      entries = assigns(:now_playing)
      expect(entries.grep(ProductionsController::FestivalBand)).to be_empty
      expect(entries.grep(Production)).to include(only_member)
    end

    it 'represents a Later This Season festival by its image, never a callout' do
      member_a = long_term_play(venue, festival: festival)
      member_b = long_term_play(venue, festival: festival)

      get :box_office

      entries = assigns(:long_term)
      expect(entries.grep(ProductionsController::FestivalBand)).to be_empty
      images = entries.grep(ProductionsController::FestivalImage)
      expect(images.size).to eq(1)
      expect(images.first.festival).to eq(festival)
      expect(entries.grep(Production)).not_to include(member_a, member_b)
    end

    it 'collapses a festival band in the Coming Soon section' do
      member_a = coming_soon_play(venue, festival: festival)
      member_b = coming_soon_play(venue, festival: festival)

      get :box_office

      bands = assigns(:coming_soon).grep(ProductionsController::FestivalBand)
      expect(bands.size).to eq(1)
      expect(bands.first.productions).to match_array([member_a, member_b])
    end

    it 'leaves inactive-festival members as loose cards' do
      inactive_festival = FactoryBot.create(:festival, :inactive)
      member = now_playing_play(venue, festival: inactive_festival)

      get :box_office

      entries = assigns(:now_playing)
      expect(entries.grep(ProductionsController::FestivalBand)).to be_empty
      expect(entries.grep(Production)).to include(member)
    end
  end
end
