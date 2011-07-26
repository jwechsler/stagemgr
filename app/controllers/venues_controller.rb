class VenuesController < ApplicationController
  layout 'ext_site_wrapper'

  def primetime_now_playing
    @venues = Venue.all.sort
  end

  def offtime_now_playing
  end

  def primetime_up_next
  end

  def offtime_up_next
  end

end
