require 'test_helper'

class OrdersControllerTest < ActionController::TestCase
  test "the credit card order makes a valid credit card payment" do
    @performance = Factory.create :performance
    @production = @performance.production
    @ticket_class = Factory.create :ticket_class, :ticket_price => 3.0
    @performance.ticket_classes << @ticket_class
    flexmock(@controller).should_receive(:admin_only).and_return(true)
    flexmock(CreditCardPayment).new_instances do |credit_card_instance|
      credit_card_instance.should_receive(:process!).and_return(true)
      credit_card_instance.should_receive(:valid?).and_return(true)
    end
    
    assert_difference('Order.count') do
      post :create, :production_id=>@production.id, :performance_id=>@performance.id, 
        "order"=>{
        "status"=>'Web',
        "production_code"=>@production.production_code,
        'performance_code'=>@performance.performance_code,
        "address_attributes"=>address_hash, 
        "credit_card_payments_attributes"=>{
          "0"=>{
            "card_expiration_month"=>'09',
            "card_expiration_year"=>'2014',
            "card_verification_number"=>'123',
            "card_number"=>'123412341234',
            "card_type"=>'American Express',
          }
        },
        "ticket_line_items_attributes"=>{
          "0"=>{
            "ticket_class_id"=>@ticket_class.id, 
            "ticket_count"=>"5"
          }
        },
      }
      assert_equal 'Your order has been created', flash[:notice]
    end
    new_order = Order.last
    assert_equal 15, new_order.total
    assert_equal 1, new_order.payments.count
    assert_equal CreditCardPayment, new_order.payments.first.class
    assert_equal 15, new_order.payments.first.amount
    assert_equal Order::PROCESSED, new_order.status
  end
end
