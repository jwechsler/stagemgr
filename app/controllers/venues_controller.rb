class VenuesController < ApplicationController
  layout 'ext_site_wrapper'

  def now_playing_fb
    self.set_now_playing_productions
    @max_pieces = 3
    render :now_playing, :layout=>'facebook'
  end
  def now_playing
    self.set_now_playing_productions
    @max_pieces = 4
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
      @offtime_productions += venue.now_playing(Production::OFF_TIME)
    end
  end
end
