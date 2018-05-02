require 'test_helper'

class PerformanceTest < ActiveSupport::TestCase
  context 'production of capacity of 10 and performance exist' do
    setup do
      without_access_control do
        @production = FactoryBot.create(:production, :capacity=>10)
        @performance = FactoryBot.create(:performance, :production=>@production)
        @order = FactoryBot.create(:ticket_order, :performance=>@performance)
      end
    end

    should "number of tickets left for a new performance should be that of the production" do
      without_access_control do
        assert_equal 10, @performance.number_of_seats_left
      end
    end


    should "number of tickets left for a performance should be decremented by orders/line items" do
      without_access_control do
        new_tickets =  FactoryBot.build(:ticket_line_item, :ticket_count=>5)
        @order.ticket_line_items <<  new_tickets
        @order.save
        @performance.reload
        assert_equal 5, @performance.number_of_seats_left
      end
    end
  end
end
