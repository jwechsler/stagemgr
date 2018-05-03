require "spec_helper.rb"

describe "a customer record" do
  it "should merge/purge production attendance records" do
    o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    original_address = o.address
    expect(original_address.productions.size).to equal(1)
    o2 = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    expect(o2.performance.production_id).not_to equal(o.performance.production_id)
    purge_address = original_address.dup
    purge_address.full_name = purge_address.full_name + "-updated"
    purge_address.save
    o2.address = purge_address
    o2.transition_to!(Order::FULFILLED)
    expect(purge_address.productions.count).to eq(1)
    original_address.merge_and_purge(purge_address)
    expect(original_address.last_name).to match(/(.*)-Updated/)
    expect(original_address.productions.size).to equal(2)
  end
end
