require "spec_helper.rb"

describe "a special offer" do

  it "can change the price of a ticket order" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets)
    o.total.should eq(10)
    offer = FactoryGirl.create(:percent_off_special_offer)
    o.special_offer_code = offer.code
    o.total.should eq(10)
    o.transition_to!(Order::PROCESSING)
    o.total.should eq(5)
  end

  it "can expire" do
    o = FactoryGirl.create(:ticket_order_for_a_pair_of_tickets)
    o.total.should eq(10)
    offer = FactoryGirl.create(:percent_off_special_offer)
    offer.auto_expire = Date.today - 1.day
    offer.save!
    o.special_offer_code = offer.code
    o.total.should eq(10)
    expect {
      o.transition_to!(Order::PROCESSING)
    }.to raise_error(RuntimeError)
  end

end
