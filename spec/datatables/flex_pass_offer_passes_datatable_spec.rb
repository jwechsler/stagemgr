require 'rails_helper'

RSpec.describe FlexPassOfferPassesDatatable do
  let(:admin) { FactoryBot.create(:admin_user) }
  let(:offer) { FactoryBot.create(:flex_pass_offer, number_of_tickets: 5) }

  before { allow(Resque).to receive(:enqueue_in) }

  # A DataTables request as the offer page's outstanding passes table sends it.
  def params(search: '')
    columns = %w[code patron order purchased expires uses_remaining].each_with_index.to_h do |column, i|
      [i.to_s, { data: column, name: '', searchable: 'true', orderable: 'true',
                 search: { value: '', regex: 'false' } }]
    end
    ActionController::Parameters.new(draw: '1', start: '0', length: '10', columns: columns,
                                     order: { '0' => { column: '4', dir: 'asc' } },
                                     search: { value: search, regex: 'false' })
  end

  def json(search: '')
    described_class.new(params(search: search), current_user: admin, flex_pass_offer: offer).as_json
  end

  def sell_pass(last_name: 'Patron')
    order = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)
    order.address.update_columns(last_name: last_name, full_name: "Pat #{last_name}")
    order.flex_pass_line_item.flex_pass
  end

  it "lists only this offer's outstanding passes" do
    outstanding = sell_pass
    sell_pass.update_columns(expiration_date: Date.current - 1)
    sell_pass.update_columns(active: false)
    exhausted = sell_pass
    FactoryBot.create(:flex_pass_payment, order: exhausted.order, flex_pass: exhausted, number_of_tickets: 5)
    FactoryBot.create(:flex_pass_order)

    result = json

    expect(result[:recordsTotal]).to eq(1)
    expect(result[:data].pluck(:DT_RowId)).to eq([outstanding.id.to_s])
  end

  it 'computes uses remaining from flex pass payments only' do
    pass = sell_pass
    FactoryBot.create(:flex_pass_payment, order: pass.order, flex_pass: pass, number_of_tickets: 2)
    FactoryBot.create(:cash_payment, order: pass.order, amount: 10).update_columns(flex_pass_id: pass.id, number_of_tickets: 1)

    expect(json[:data].first[:uses_remaining]).to eq('3')
  end

  it 'searches by code and by patron last name' do
    smith = sell_pass(last_name: 'Smithers')
    jones = sell_pass(last_name: 'Jonesy')

    expect(json(search: smith.code)[:data].pluck(:DT_RowId)).to eq([smith.id.to_s])
    expect(json(search: 'Jonesy')[:data].pluck(:DT_RowId)).to eq([jones.id.to_s])
  end

  it "shows the order's patron when the pass points at a deleted address" do
    pass = sell_pass(last_name: 'Current')
    pass.update_columns(address_id: Address.maximum(:id) + 1)

    row = json[:data].first

    expect(row[:patron]).to include('Pat Current', "/addresses/#{pass.order.address_id}")
    expect(json(search: 'Current')[:data].pluck(:DT_RowId)).to eq([pass.id.to_s])
  end

  it 'flags a pass whose order is not yet fulfilled and leaves fulfilled ones blank' do
    unfulfilled = sell_pass
    fulfilled = sell_pass
    fulfilled.order.update_columns(status: Order::FULFILLED)

    rows = json[:data].index_by { |row| row[:DT_RowId] }

    expect(rows[unfulfilled.id.to_s][:fulfillment]).to include('Unfulfilled')
    expect(rows[fulfilled.id.to_s][:fulfillment]).to eq('')
  end

  it 'renders a dash for a legacy pass without an address or line item' do
    sell_pass.update_columns(address_id: nil, flex_pass_line_item_id: nil)

    row = json[:data].first

    expect(row[:patron]).to eq('—')
    expect(row[:order]).to eq('—')
  end

  it 'links the patron and the order and formats the dates' do
    pass = sell_pass(last_name: 'Linked')

    row = json[:data].first

    expect(row[:patron]).to include('Pat Linked', "/addresses/#{pass.address_id}")
    expect(row[:order]).to include("Order #{pass.flex_pass_line_item.order_id}")
    expect(row[:expires]).to eq(pass.expiration_date.to_formatted_s(:numeric_date))
  end
end
