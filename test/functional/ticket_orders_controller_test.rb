require 'test_helper'

class TicketOrdersControllerTest < ActionController::TestCase
  test "the credit card order makes a valid credit card payment" do
    without_access_control do
      @credit_card_payment_type = Factory.create(:credit_card_payment_type)
    @performance = Factory.create :performance
    @production = @performance.production
    @ticket_class = Factory.create :ticket_class, :ticket_price => 3.0
    @performance.ticket_classes << @ticket_class
    flexmock(@controller).should_receive(:admin_only).and_return(true)
    flexmock(CreditCardPayment).new_instances do |credit_card_instance|
      #credit_card_instance.should_receive(:process!).and_return(true)
      #credit_card_instance.should_receive(:valid?).and_return(true)
    end
    authorize_net_response = flexmock('authorize_net_response')
    authorize_net_response.should_receive(:authorization).and_return(35)
    authorize_net_response.should_receive(:success?).and_return(true)
    authorize_net_response.should_receive(:params).and_return({:transaction_id=>'success0001'})
    flexmock(ActiveMerchant::Billing::PaypalGateway).new_instances.should_receive(:purchase).and_return(authorize_net_response)

    assert_difference('Order.count') do
        post :create, :commit=>'Place Order', :production_id=>@production.id, :performance_id=>@performance.id,
          "ticket_order"=>{
          "status"=>Order::NEW,
          "production_code"=>@production.production_code,
          'performance_code'=>@performance.performance_code,
          "address_attributes"=>address_hash,
          "payment_type_id"=>@credit_card_payment_type.id,
          "credit_card_expiration_month"=>'09',
          "credit_card_expiration_year"=>'2014',
          "credit_card_verification_number"=>'123',
          "credit_card_number"=>'4111111111111111',
          "credit_card_type"=>'Visa',
          "ticket_line_items_attributes"=>{
            "0"=>{
              "ticket_class_id"=>@ticket_class.id,
              "ticket_count"=>"5"
            }
          },
        }
      assert_equal 'Order was successfully saved and is now Processed', flash[:notice]
      end
    end
    new_order = Order.last
    assert_equal 15, new_order.total_paid
    assert_equal 1, new_order.payments.count
    assert_equal CreditCardPayment, new_order.payments.first.class
    assert_equal 15, new_order.payments.first.amount
    assert_equal Order::PROCESSED, new_order.status
  end
end
