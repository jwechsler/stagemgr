require 'test_helper'

class DefaultTicketClassTest < ActiveSupport::TestCase
  def test_should_be_valid
    assert DefaultTicketClass.new.valid?
  end
end
