require 'rails_helper'

RSpec.describe FlexPassPatronReport do
  let(:starting_date) { Date.today - 7 }
  let(:ending_date) { Date.today }

  let(:wit_offer)    { FactoryBot.create(:flex_pass_offer, name: 'Wit Pass') }
  let(:roving_offer) { FactoryBot.create(:flex_pass_offer, name: 'Roving Pass') }

  let!(:wit_order)    { FactoryBot.create(:flex_pass_order, flex_pass_offer: wit_offer) }
  let!(:roving_order) { FactoryBot.create(:flex_pass_order, flex_pass_offer: roving_offer) }

  def order_numbers(report_output)
    report_output.last.map { |row| row[:flex_pass_order_number] }
  end

  it 'includes every order in range when no offers are selected' do
    output = described_class.new(starting_date, ending_date).create
    expect(order_numbers(output)).to contain_exactly(wit_order.id, roving_order.id)
  end

  it 'restricts to the selected offers' do
    output = described_class.new(starting_date, ending_date, [wit_offer.id]).create
    expect(order_numbers(output)).to contain_exactly(wit_order.id)
  end

  it 'accepts several offer ids' do
    output = described_class.new(starting_date, ending_date, [wit_offer.id, roving_offer.id]).create
    expect(order_numbers(output)).to contain_exactly(wit_order.id, roving_order.id)
  end

  it 'lists every pass of a legacy multi-pass line item exactly once' do
    original_code = wit_order.flex_pass.code
    line_item = wit_order.flex_pass.flex_pass_line_item
    FlexPass.create!(flex_pass_line_item: line_item, flex_pass_offer: wit_offer,
                     address: wit_order.address, code: 'SECONDCODE',
                     expiration_date: Date.today + 12.months, active: true)

    rows = described_class.new(starting_date, ending_date, [wit_offer.id]).create.last
    expect(rows.length).to eq(2)
    expect(rows.pluck(:flex_pass_code)).to contain_exactly(original_code, 'SECONDCODE')
    expect(rows.pluck(:flex_pass_order_number).uniq).to eq([wit_order.id])
  end
end
