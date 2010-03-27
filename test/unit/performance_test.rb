require 'test_helper'

class PerformanceTest < ActiveSupport::TestCase
  context 'production of capacity of 10 and performance exist' do
    setup do
      @production = Factory.create(:production, :capacity=>10)
      @performance = Factory.create(:performance, :production=>@production)
    end
      
    should "number of tickets left for a new perfomance should be that of the production" do
      assert_equal 10, @performance.number_of_tickets_left
    end

    should "number of tickets left for a perfomance should be decremented by orders/line items" do
      Factory.create(:line_item, :performance=>@performance, :ticket_count=>5)
      assert_equal 5, @performance.number_of_tickets_left
    end
  end
end
