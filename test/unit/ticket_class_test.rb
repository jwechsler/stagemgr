require 'test_helper'

class TicketClassTest < ActiveSupport::TestCase
  test "the ticket class knows how many tickets are left for a performance" do
    without_access_control do
      production = FactoryGirl.create(:production, :capacity=>10)
      performance = FactoryGirl.create(:performance, :production=>production)
      ticket_class = FactoryGirl.create(:ticket_class, :production=>production)
      assert_equal 10, ticket_class.number_left(performance)
    end
  end

  test "if the ticket class limit is nil then the ticket limit is the production capacity" do
    without_access_control do
      production = FactoryGirl.create(:production, :capacity=>10)
      performance = FactoryGirl.create(:performance, :production=>production)
      ticket_class = FactoryGirl.create(:ticket_class, :production=>production)
      performance.ticket_class_allocations.create(:ticket_class=>ticket_class)
      assert_equal 10, ticket_class.number_left(performance)
    end
  end

  test "if the ticket class allocation has a limit the the number left should be that" do
    without_access_control do
      production = FactoryGirl.create(:production, :capacity=>10)
      performance = FactoryGirl.create(:performance, :production=>production)
      ticket_class = FactoryGirl.create(:ticket_class, :production=>production)
      performance.ticket_class_allocations.create(:ticket_class=>ticket_class, :ticket_limit=>5)
      assert_equal 5, ticket_class.number_left(performance)
    end
  end
end
