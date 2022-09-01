require 'rails_helper'

RSpec.describe "a donation order" do

  context "when a single donation" do

    it "should process a one-time payment accurately" do
      @donation = FactoryBot.create(:donation_order_for_one_thousand_dollars)
      expect(@donation.status).to eq(Order::HOLD)
      expect(@donation.total).to eq(1000.00)
      expect(@donation.total_paid).to eq(0.0)
      @donation.payment_type = FactoryBot.create(:cash_payment_type)
      @donation.transition_to!(Order::PROCESSED)

      expect(@donation.total_paid).to eq(1000.0)
      expect(@donation.total).to eq(1000.00)

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