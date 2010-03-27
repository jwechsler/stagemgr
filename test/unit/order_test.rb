require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  context 'production of capacity of 10 and performance exist' do
    setup do
      @production = Factory.create(:production, :capacity=>10)
      @ticket_class = Factory.create(:ticket_class, :production=>@production)
      @performance = Factory.create(:performance, :production=>@production)
    end
      
    should "A held order reduces the quantity of tickets available for the performance" do
      o = Order.create!(:status=>'Held')
      li = o.line_items.create!(:performance=>@performance, :ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 5, @performance.number_of_tickets_left
    end

    should "A processed order reduces the quantity of tickets available for the performance" do
      o = Order.create!(:status=>'Processed')
      li = o.line_items.create!(:performance=>@performance, :ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 5, @performance.number_of_tickets_left
    end

    should "A canceled order does not reduce the quantity of tickets available for the performance" do
      o = Order.create!(:status=>'Canceled')
      li = o.line_items.create!(:performance=>@performance, :ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 10, @performance.number_of_tickets_left
    end

    should "A refunded order does not reduce the quantity of tickets available for the performance" do
      o = Order.create!(:status=>'Refunded')
      li = o.line_items.create!(:performance=>@performance, :ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 10, @performance.number_of_tickets_left
    end

    should "available tickets for a performance cannot drop below 0" do
      o = Order.create!(:status=>'Held')
      li = o.line_items.build(:performance=>@performance, :ticket_class=>@production.ticket_classes.first, :ticket_count=>11)
      assert_false li.save
    end

    should "orders can be in Held, Canceled, Processed, or Refunded status" do
      o = Order.create!(:status=>'Held')
      o = Order.create!(:status=>'Canceled')
      o = Order.create!(:status=>'Processed')
      o = Order.create!(:status=>'Refunded')
    end
  end
end
