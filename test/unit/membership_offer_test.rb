require 'test_helper'

class MembershipOfferTest < ActiveSupport::TestCase
  def test_should_be_valid
    assert MembershipOffer.new.valid?
  end
end
