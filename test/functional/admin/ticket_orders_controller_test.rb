require 'test_helper'

class Admin::TicketOrdersControllerTest < ActionController::TestCase
  test "the cash order makes a valid cash payment" do
    without_access_control do
      @performance = FactoryGirl.create :performance
      @production = @performance.production
      @ticket_class = FactoryGirl.create :ticket_class, :ticket_price => 3.0
      @performance.ticket_classes << @ticket_class
      @payment_type = FactoryGirl.create :cash_payment_type
      flexmock(@controller).should_receive(:admin_only).and_return(true)
      assert_difference('Order.count') do
        post :create, :commit=>'Place Order',
             "ticket_order"=>{
                 "address_attributes"=>address_hash,
                 "performance_code"=>@performance.performance_code,
                 "ticket_line_items_attributes"=>{
                     "0"=>{
                         "ticket_class_code"=>@ticket_class.class_code,
                         "ticket_count"=>"5"
                     }
                 },
                 "payment_type_id"=>@payment_type.id,
                 "production_code"=>@production.production_code
             }
        assert_equal 'Order was successfully saved and is now Processed', flash[:notice]
      end
      new_order = Order.last
      assert_equal 15, new_order.total
      assert_equal Order::PROCESSED, new_order.status
      assert_equal 1, new_order.payments.count
      assert_equal CashPayment, new_order.payments.first.class
      assert_equal 15, new_order.payments.first.amount
      assert_equal Order::PROCESSED, new_order.status
    end
  end

  test "the credit card order makes a valid credit card payment" do
    without_access_control do
      @performance = FactoryGirl.create :performance
      @production = @performance.production
      @ticket_class = FactoryGirl.create :ticket_class, :ticket_price => 3.0
      @performance.ticket_classes << @ticket_class
      @payment_type = FactoryGirl.create :credit_card_payment_type
      flexmock(@controller).should_receive(:admin_only).and_return(true)
      flexmock(CreditCardPayment).new_instances do |credit_card_instance|
        credit_card_instance.should_receive(:process!).and_return(true)
        credit_card_instance.should_receive(:valid?).and_return(true)
      end

      assert_difference('Order.count') do
        post :create, :commit=>'Place Order',
             "ticket_order"=>{
                 "address_attributes"=>address_hash,
                 "performance_code"=>@performance.performance_code,
                 "credit_card_expiration_month"=>'09',
                 "credit_card_expiration_year"=>'2014',
                 "credit_card_verification_number"=>'123',
                 "credit_card_number"=>'123412341234',
                 "credit_card_type"=>'American Express',
                 "ticket_line_items_attributes"=>{
                     "0"=>{
                         "ticket_class_code"=>@ticket_class.class_code,
                         "ticket_count"=>"5"
                     }
                 },
                 "payment_type_id"=>@payment_type.id,
                 "production_code"=>@production.production_code
             }
        assert_equal 'Order was successfully saved and is now Processed', flash[:notice]
      end
      new_order = Order.last
      assert_equal 15, new_order.total
      assert_equal 1, new_order.payments.count
      assert_equal CreditCardPayment, new_order.payments.first.class
      assert_equal 15, new_order.payments.first.amount
      assert_equal Order::PROCESSED, new_order.status
    end
  end
end