require 'test_helper'

class SpecialFeatureTest < ActiveSupport::TestCase
  def test_should_be_valid
    assert SpecialFeature.new.valid?
  end
end
