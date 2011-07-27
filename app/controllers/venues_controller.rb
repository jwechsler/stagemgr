class VenuesController < ApplicationController
  layout 'ext_site_wrapper'

  def primetime_now_playing
    @venues = Venue.all.select{|v|
      p = v.now_playing_or_next_up(Production::PLAY)
      !p.empty?}.sort
    @offtime_productions = Array.new
    @venues.each do |venue|
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
