require 'rails_helper'

RSpec.describe TicketOrder, '#build_tktprint_payload with virtual, other and add-on classes' do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

  def add_class(code, admission)
    # None holds a seat: a stream, a tablet reservation, and a drink add-on.
    ticket_class = FactoryBot.create(:ticket_class,
                                     production: order.performance.production,
                                     class_code: code,
                                     holds_seats: false,
                                     admission: admission)
    FactoryBot.create(:ticket_class_allocation,
                      performance: order.performance,
                      ticket_class: ticket_class,
                      ticket_limit: 10)
    FactoryBot.create(:ticket_line_item, ticket_class: ticket_class, ticket_count: 1, order: order)
  end

  before do
    add_class('STRM', 'virtual')
    add_class('TABL', 'other')
    add_class('DRNK', 'in_person')
    order.reload
  end

  let(:payload) { order.send(:build_tktprint_payload, 'BATCH-1', 1) }
  let(:printed_codes) { payload[:tickets_attributes].pluck(:ticket_class) }

  it 'prints the in-person tickets, including a non-seat add-on, but not the stream or reservation' do
    in_person_count = order.admission_ticket_count('in_person')

    expect(printed_codes).to include('DRNK')
    expect(printed_codes).not_to include('STRM', 'TABL')
    expect(printed_codes.length).to eq(in_person_count)
  end

  it 'still lists the virtual and other classes among the receipt line items' do
    descriptions = payload[:line_items_attributes].pluck(:description)

    expect(descriptions).to include(a_string_including('STRM'), a_string_including('TABL'))
  end
end
