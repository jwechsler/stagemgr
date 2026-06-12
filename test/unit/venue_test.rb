require 'test_helper'

class VenueTest < ActiveSupport::TestCase
  def test_should_be_valid
    v = Venue.new
    v.name = "Test"
    v.ordinal_sort = "Test"
    assert v.valid?
  end
end
