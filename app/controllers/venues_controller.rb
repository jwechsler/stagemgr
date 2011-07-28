class VenuesController < ApplicationController
  layout 'ext_site_wrapper'

  def now_playing
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

  def offtime_now_playing
  end

  def primetime_up_next
  end

  def offtime_up_next
  end

end
