require 'rails_helper'

RSpec.describe "order with service line items" do

  it "can have multiple order processing fees"  do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)
    initial_cost = o.total
    initial_fee = o.ticketing_fee
    service_line_item = FactoryBot.create(:service_line_item, :facility_fee=>2.00, :amount=>20.0, :order=>o)
    o.service_line_items << service_line_item
    expect(o.total).to eq(service_line_item.amount + initial_cost)
    service2 = FactoryBot.create(:service_line_item, :facility_fee=>1.00, :amount=>5.0, :order=>o)
    o.service_line_items << service2
    expect(o.total).to eq(service_line_item.amount + initial_cost + 5)

    o.transition_to!(Order::PROCESSED)
    expect(o.total_paid).to eq(service_line_item.amount + initial_cost + 5)
    expect(o.ticketing_fee).to eq(initial_fee + 3)
  end

end
