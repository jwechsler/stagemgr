# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HouseManagementReport, type: :model do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:report_date) { Date.current }
  let(:production) { FactoryBot.create(:production) }
  # Created before the performance, which snapshots the production's ticket
  # classes (the factory find_or_creates by class_code, so the code is unique).
  let!(:ticket_class) do
    FactoryBot.create(:ticket_class, class_code: 'HMRREG', complimentary: false, production: production)
  end
  let(:performance) { FactoryBot.create(:performance, production: production, performance_date: report_date) }

  def attending_order_for(address)
    order = FactoryBot.create(:ticket_order, address: address, performance: performance)
    order.ticket_line_items << FactoryBot.build(:ticket_line_item, order: order,
                                                                   ticket_class: ticket_class, ticket_count: 1)
    order.update!(status: Order::FULFILLED)
    order
  end

  def report_rows
    report = described_class.new(report_date)
    allow(report).to receive(:save_report_to_filestore)
    _headers, rows = report.create
    rows
  end

  def row_for(address)
    report_rows.find { |row| row[:patron_name] == address.full_name }
  end

  it 'leaves off a patron whose only tags are LGL ID and LGL Review' do
    address = FactoryBot.create(:address)
    address.set_lgl_id!(4242)
    address.lgl_review!('Also LGL constituent 99')
    attending_order_for(address)

    expect(row_for(address)).to be_nil
  end

  it 'leaves off a patron whose only tag is LGL Lapsed' do
    address = FactoryBot.create(:address)
    address.set_lgl_lapsed!('LYBUNT')
    attending_order_for(address)

    expect(row_for(address)).to be_nil
  end

  it 'lists a patron with a house tag and prints it' do
    address = FactoryBot.create(:address)
    address.address_tags.create!(tag_label: 'Wheelchair', tag_value: 'aisle', theater: house)
    attending_order_for(address)

    expect(row_for(address)[:notes]).to include('Patron Notes:').and include('Wheelchair (aisle)')
  end

  it 'prints only the house tag when the patron also has LGL tags' do
    address = FactoryBot.create(:address)
    address.address_tags.create!(tag_label: 'Wheelchair', theater: house)
    address.set_lgl_id!(4242)
    address.set_lgl_lapsed!('SYBUNT')
    attending_order_for(address)

    notes = row_for(address)[:notes]
    expect(notes).to include('Wheelchair')
    expect(notes).not_to include(AddressTag::LGL_ID)
    expect(notes).not_to include('4242')
    expect(notes).not_to include(AddressTag::LGL_LAPSED)
    expect(notes).not_to include('SYBUNT')
  end
end
