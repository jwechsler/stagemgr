require 'rails_helper'

RSpec.describe VenuesController, type: :controller do
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

  def next_up_play(venue)
    open = Date.today + 2.weeks
    FactoryBot.create(:production,
                      venue: venue,
                      status: Production::ACTIVE,
                      production_class: Production::PLAY,
                      first_preview_at: open,
                      opening_at: open,
                      press_opening_at: open,
                      closing_at: open + 2.weeks)
  end

  describe 'GET #now_playing' do
    let(:venue) { FactoryBot.create(:venue) }
    let(:festival) { FactoryBot.create(:festival) }

    it 'partitions active-festival members into @festival_blocks instead of thumbs' do
      member = now_playing_play(venue, festival: festival)

      get :now_playing

      blocks = assigns(:festival_blocks)
      expect(blocks.size).to eq(1)
      expect(blocks.first[:festival]).to eq(festival)
      expect(assigns(:now_playing_productions)).not_to include(member)
    end

    it 'exposes featured and full production lists per block' do
      now_playing_play(venue, festival: festival)
      extra = now_playing_play(venue, festival: festival)
      # featured_productions requires an active, non-past performance
      FactoryBot.create(:performance, production: extra, performance_date: Date.today)

      get :now_playing

      block = assigns(:festival_blocks).first
      expect(block[:featured].to_a).to include(extra)
      expect(block[:all].to_a).to include(extra)
    end

    it 'surfaces the venue next non-festival show when the current show is in the festival' do
      now_playing_play(venue, festival: festival)
      upcoming = next_up_play(venue)

      get :now_playing

      expect(assigns(:now_playing_productions)).to include(upcoming)
    end

    it 'builds no festival blocks when no active-festival shows are playing' do
      now_playing_play(venue)

      get :now_playing

      expect(assigns(:festival_blocks)).to be_empty
    end
  end
end
