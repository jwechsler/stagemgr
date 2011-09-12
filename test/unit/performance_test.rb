require 'test_helper'

class PerformanceTest < ActiveSupport::TestCase
  context 'production of capacity of 10 and performance exist' do
    setup do
      without_access_control do
        @production = Factory.create(:production, :capacity=>10)
        @performance = Factory.create(:performance, :production=>@production)
        @order = Factory.create(:ticket_order, :performance=>@performance)
      end
    end

    should "number of tickets left for a new perfomance should be that of the production" do
      without_access_control do
        assert_equal 10, @performance.number_of_tickets_left
      end
    end


    should "number of tickets left for a performance should be decremented by orders/line items" do
      without_access_control do
        Factory.create(:ticket_line_item, :order=>@order, :ticket_count=>5)
        assert_equal 5, @performance.number_of_tickets_left
      end
    end
  end
end
