require 'rails_helper'

shared_examples_for RecurringProfile do
  before(:each) do
    @paypal_callback.merge!({'recurring_payment_id' => PaymentProcessing::BogusResponse::PROFILE_ID})
  end
  context "when receiving new recurrent payment via ipn" do
    before(:each) do
      @paypal_callback.merge!({'invoice'=>@order.id.to_s,
                         'amount'=>'10',
                         'txn_type'=>'recurring_payment'})
      @paypal_callback['txn_id'] = @order.payments.first.transaction_id unless @order.payments.empty?
    end

    it "should enqueue an additional payment against the order" do
      Resque.should_receive(:enqueue).with(
        ProcessRecurringPaypalPayment,
        @paypal_callback
      ).once
      PayPalControllerHelper.process_paypal_ipn_request('recurring_payment', @paypal_callback)
    end

    it "should update the order payments" do
      start_num_payments = @order.payments.count
      old_total = @order.total_collected
      ProcessRecurringPaypalPayment.perform(@paypal_callback)
      @order.payments(true)
      @order.payments.count.should eq(start_num_payments+1)
      @order.total.should eq(old_total+10.0)
    end
  end

  context "when receiving a suspension notification via ipn" do
    before(:each) do
      @paypal_callback['txn_type']='recurring_payment_suspended'
    end

    it "should enqueue a suspension request" do
      Resque.should_receive(:enqueue).with(
        ProcessSuspendRecurringPaypalPayment,
        @paypal_callback
      ).once
      PayPalControllerHelper.process_paypal_ipn_request('recurring_payment_suspended', @paypal_callback)
    end

    it "should suspend the profile" do
      @order.recurring_profile.status.should_not eq(RecurringProfile::SUSPENDED)
      ProcessSuspendRecurringPaypalPayment.perform(@paypal_callback)
      @order.recurring_profile.reload
      @order.recurring_profile.status.should eq(RecurringProfile::SUSPENDED)
    end

  end

  context "when receiving a cancellation notification via ipn" do
    before(:each) do
      @paypal_callback['txn_type']='recurring_payment_profile_cancel'
    end

    it "should enqueue a cancellation request" do
      Resque.should_receive(:enqueue).with(
        ProcessCancelRecurringPaypalPayment,
        @paypal_callback
      ).once
      PayPalControllerHelper.process_paypal_ipn_request('recurring_payment_profile_cancel', @paypal_callback)
    end

    it "should cancel the profile" do
      @order.recurring_profile.status.should_not eq(Membership::CANCELED)
      ProcessCancelRecurringPaypalPayment.perform(@paypal_callback)
      @order.recurring_profile.reload
      @order.recurring_profile.status.should eq(Membership::CANCELED)
    end
  end
end

RSpec.describe PayPalControllerHelper do
  before (:each) do
    @paypal_callback = {'ipn_track_id'=>'IPNTRACK1',
                        'payment_date'=>DateTime.now.to_formatted_s(:paypal),
                        'payment_fee'=>'0.30'
                      }
  end
  context "when recieving 'web_accept' ipn" do
    before (:each) do
      @order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_credit_card)
      @paypal_callback.merge!({'invoice'=>@order.id.to_s,
                         'txn_id'=>@order.payments.first.transaction_id,
                         'amount'=>@order.payments.first.amount.to_s,
                         'txn_type'=>'web_accept'})
    end

    it "should enqueue update of payment for a placed order" do
      @order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_credit_card)
      Resque.should_receive(:enqueue_in).with(
        5.seconds,
        ProcessPaypalPayment,
        @paypal_callback
      ).once
      PayPalControllerHelper.process_paypal_ipn_request('web_accept', @paypal_callback)
    end

    it "should update the payment amount" do
      @order.payments.first.payment_fee.should be_nil
      ProcessPaypalPayment.perform(@paypal_callback)
      @order.payments(true) #reload payments
      @order.payments.first.amount.should eq(10)
      @order.payments.first.payment_fee.should eq(0.30)
    end
  end

  describe "for recurring payments" do

    context "for memberships" do

      before(:each) do
        @order = FactoryBot.create(:membership_order)
      end

      it_behaves_like RecurringProfile

    end

    context "for pledges" do
      before(:each) do
        @order = FactoryBot.create(:donation_pledge_order_for_one_thousand_dollars_using_credit_card)
      end

      it_behaves_like RecurringProfile
    end
  end
end
