require 'rails_helper'

RSpec.describe "a donation order" do

  context "when a single donation" do

    it "should process a one-time payment accurately" do
      @donation = FactoryBot.create(:donation_order_for_one_thousand_dollars)
      expect(@donation.status).to eq(Order::HOLD)
      expect(@donation.total).to eq(1000.00)
      expect(@donation.value_of_all_payments).to eq(0.0)
      @donation.payment_type = FactoryBot.create(:cash_payment_type)
      @donation.transition_to!(Order::PROCESSED)

      expect(@donation.value_of_all_payments).to eq(1000.0)
      expect(@donation.total).to eq(1000.00)

    end

    it "should allow a monthly pledge" do
      @donation = FactoryBot.create(:donation_pledge_order_for_one_thousand_dollars)
      expect(@donation.status).to eq(Order::HOLD)
      expect(@donation.total).to eq(1000.00)
      expect(@donation.value_of_all_payments).to eq(0.0)
      expect(@donation.pledge).to be_nil
      @donation.payment_type = FactoryBot.create(:credit_card_payment_type)
      @donation.credit_card_number = '4111111111111111'
      @donation.credit_card_type = 'Visa'
      @donation.credit_card_expiration_year = Date.today.year+1
      @donation.credit_card_expiration_month = Date.today.month
      @donation.credit_card_verification_number = '999'
      @donation.transition_to!(Order::PROCESSED)
      expect(@donation.pledge).not_to be_nil
      expected = 12000
      expect(@donation.total).to eq(expected)

      expect(@donation.pledge.final_payment_due_date).to eq(Date.today+12.months)
      expect(@donation.value_of_all_payments).to eq(0.0)
    end

# This is no longer the desired behavior.  Leads to race conditions for remote updates...  Needs further thought
#    it "should update address aggregate donations" do
#      @donation = FactoryBot.create(:donation_order_for_one_thousand_dollars)
#      @donation.payment_type = FactoryBot.create(:cash_payment_type)
#      @donation.transition_to!(Order::PROCESSED)
#      @donation.address.donated_this_year.should eq(Money.new(100000))
#      @donation.address.donated_last_n_days.should eq(Money.new(100000))
#      @donation.address.donated_last_year.should eq(Money.new(0))
#    end

  end

end