require 'test_helper'
include Authorization::Maintenance

class OrderTaskTest < ActiveSupport::TestCase


  context "given a new order" do
    setup do
      without_access_control do
        @order = FactoryGirl.create(:ticket_order)
        @order.address = addresses(:jeremy)
        @order.performance = performances(:macbeth_opening)
        @order.ticket_line_items << TicketLineItem.new({:ticket_class => ticket_classes(:macbeth_general_admission), :ticket_count => 1})
      end
    end
    should "generate two outreach tasks when processed" do
      @order.transition_to!(Order::PROCESSING)
      assert_equal(0, @order.tasks.size)
      @order.transition_to!(Order::PROCESSED)
      assert_equal(2, @order.tasks.size)
      task1=@order.tasks[0]
      task2=@order.tasks[1]
      assert_true(task1.is_a? OutreachTask)
      assert_true(@order.tasks[1].is_a? OutreachTask)
      assert_equal('ticket_confirmation', task1.method_symbol.to_s)
      assert_true(task2.execute_at > @order.performance.performance_date - 2.day)
      assert_true(task2.execute_at < @order.performance.performance_date)
    end

    should "generate a followup task for after the performance when fulfilled" do
      @order.transition_to!(Order::PROCESSING)
      @order.transition_to!(Order::PROCESSED)
      @order.transition_to!(Order::FULFILLED)
      assert_equal(3, @order.tasks.size)
      task3 = @order.tasks[2]
      assert_equal('first_time_followup', task3.method_symbol.to_s)
    end

    should "generate a different followup task for the second order" do
      @order.transition_to!(Order::PROCESSING)
      @order.transition_to!(Order::PROCESSED)
      @order2 = Factory.create(:ticket_order, :address => addresses(:jeremy), :payment_type => Order::CASH, :status => Order::NEW,
                               :performance => performances(:macbeth_matinee))
      @order2.ticket_line_items << TicketLineItem.new({:ticket_class => ticket_classes(:macbeth_general_admission), :ticket_count => 1})

      @order2.transition_to!(Order::PROCESSING)
      @order2.transition_to!(Order::PROCESSED)
      assert_equal(2, @order2.tasks.size)
      @order2.transition_to!(Order::FULFILLED)
      assert_equal(3, @order2.tasks.size)
      assert_equal('standard_followup', @order2.tasks[2].method_symbol.to_s)
    end

  end

end
