'exclass VenuesController < ApplicationController
  layout $SERVER_CONFIG['ext_site_wrapper']
  before_action :set_background

  def now_playing_fb
    self.set_now_playing_productions
    @now_playing_productions += @offtime_productions
    @home_shows = @now_playing_productions.select{|prod| prod.theater.producing?}
    @now_playing_productions -= @home_shows
    @max_pieces = 3
    render :now_playing_fb, :layout=>'facebook'
  end

  def now_playing
    self.set_now_playing_productions
    @max_pieces = 4
    respond_to do |format|
      format.html { render :layout => false } # your-action.html.erb
    end
  end

  def now_playing_vertical
    self.set_background
    self.set_now_playing_productions
  end

  def set_background
    @background = params['background']
    @background = 'light' if @background.nil?
    @background = 'light' unless ['light','dark'].include?(@background)
  end

  def current_shows
    @now_playing_productions = now_playing_by_venue(Production::PLAY) + now_playing_by_venue(Production::OFF_TIME)
  end

  def offtime_now_playing
  end

  def primetime_up_next
  end

  def offtime_up_next
  end

  def now_playing_by_venue(production_type)
    now_playing_productions = Array.new
    Venue.all.sort.each do |venue|
      prods = venue.now_playing_or_next_up(production_type)
      now_playing_productions += prods
    end
    now_playing_productions
  end

  protected
  def set_now_playing_productions
    @now_playing_productions = Array.new
    Venue.all.sort.each do |venue|
      prods = venue.now_playing_or_next_up(Production::PLAY)
      @now_playing_productions += prods
    end
    @offtime_productions = Array.new
    Venue.all.each do |venue|
      @offtime_productions += venue.now_playing(Production::OFF_TIME, Date.today.end_of_week + 3.days)
    end
  end
end
