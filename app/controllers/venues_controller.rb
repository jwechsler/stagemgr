class VenuesController < ApplicationController
  layout Rails.configuration.x.server_config['ext_site_wrapper']
  before_action :set_background

  def now_playing_fb
    set_now_playing_productions
    @now_playing_productions += @offtime_productions
    @home_shows = @now_playing_productions.select { |prod| prod.theater.producing? }
    @now_playing_productions -= @home_shows
    @max_pieces = 3
    render :now_playing_fb, layout: 'facebook'
  end

  def now_playing
    set_now_playing_productions
    @max_pieces = 4
    respond_to do |format|
      format.html { render layout: false } # your-action.html.erb
    end
  end

  def now_playing_vertical
    set_background
    set_now_playing_productions
  end

  def set_background
    @background = params['background']
    @background = 'light' if @background.nil?
    @background = 'light' unless %w[light dark].include?(@background)
  end

  def current_shows
    @now_playing_productions = now_playing_by_venue(Production::PLAY) + now_playing_by_venue(Production::OFF_TIME)
  end

  def offtime_now_playing; end

  def primetime_up_next; end

  def offtime_up_next; end

  def now_playing_by_venue(production_type)
    now_playing_productions = []
    Venue.all.sort.each do |venue|
      prods = venue.now_playing_or_next_up(production_type)
      now_playing_productions += prods
    end
    now_playing_productions
  end

  protected

  def set_now_playing_productions
    festival_members = []
    @now_playing_productions = []
    Venue.all.sort.each do |venue|
      if venue.external?
        prods = venue.now_playing(Production::PLAY, Date.today.end_of_week + 1.week)
        members, others = prods.partition { |p| p.festival&.active? }
        festival_members += members
        @now_playing_productions += others
      else
        # exclude_festival keeps a festival show from occupying the venue slot so
        # the venue still surfaces its next non-festival show as a thumb.
        festival_members += venue.now_playing(Production::PLAY).select { |p| p.festival&.active? }
        @now_playing_productions += venue.now_playing_or_next_up(Production::PLAY, exclude_festival: true)
      end
    end
    @offtime_productions = []
    Venue.all.each do |venue|
      prods = venue.now_playing(Production::OFF_TIME, Date.today.end_of_week + 3.days)
      members, others = prods.partition { |p| p.festival&.active? }
      festival_members += members
      @offtime_productions += others
    end
    build_festival_blocks(festival_members)
  end

  # Active-festival members never render as loose venue thumbs; group them into
  # blocks that render after the per-venue listings.
  def build_festival_blocks(festival_members)
    @festival_blocks = festival_members.map(&:festival).uniq.map do |festival|
      { festival: festival, featured: festival.featured_productions(3), all: festival.public_productions }
    end
  end
end
