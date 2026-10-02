require 'rails_helper'
require 'stripe_mock'

# Reserved-seating ticket orders keep one TicketLineItem per seat, linked by
# seat_assignment_id. The import used to build one aggregated, unlinked line
# item for all of a row's seats.
RSpec.describe BulkOrderImport do
  before { StripeMock.start }
  after  { StripeMock.stop }

  let(:user) { User.create!(email: 'importer@example.com', password: 'sekritsekrit') }
  let(:performance) { FactoryBot.create(:reserved_seating) }
  let(:production) { performance.production }
  let(:ticket_class) { production.ticket_classes.where(holds_seats: true).order(:id).first }
  let(:seat_assignments) { SeatAssignment.available_seat_assignments(performance).sort_by(&:id) }

  def filestore_for(csv)
    file_store = FileStore.new(user: user, worker: FileStore::IMPORT, notes: 'Order import')
    file_store.datafile.attach(io: StringIO.new(csv), filename: 'orders.csv', content_type: 'text/csv')
    file_store.save!
    file_store
  end

  def run(seating: nil, count: nil, payment_type_id: FactoryBot.create(:cash_payment_type).id.to_s)
    csv = <<~CSV
      PerformanceCode,TicketClass,Seating,NumberOfTickets,FullName,EmailAddress1
      #{performance.performance_code},#{ticket_class.class_code},"#{seating}",#{count},Casey Patron,patron@example.com
    CSV
    described_class.perform(filestore_for(csv).id, production.theater_id, payment_type_id, false)
  end

  def locations(sas)
    sas.map { |sa| Seat.find(sa.seat_id).location }
  end

  context 'with a Seating list' do
    let(:picked) { seat_assignments.first(2) }

    it 'creates one linked line item per seat' do
      run(seating: locations(picked).join(','))

      order = TicketOrder.last
      expect(order.ticket_line_items.map { |li| [li.ticket_count, li.ticket_class_id, li.seat_assignment_id] })
        .to match_array(picked.map { |sa| [1, ticket_class.id, sa.id] })
      expect(SeatAssignment.where(id: picked.map(&:id)).pluck(:status, :order_uuid, :ticket_class_id).uniq)
        .to eq([[SeatAssignment::ASSIGNED, order.uuid, ticket_class.id]])
    end

    it 'accepts spaces after the commas' do
      run(seating: locations(picked).join(', '))
      expect(TicketOrder.last.ticket_line_items.map(&:seat_assignment_id)).to match_array(picked.map(&:id))
    end

    it 'holds the seats when there is no payment type' do
      run(seating: locations(picked).join(','), payment_type_id: '')
      order = TicketOrder.last
      expect(order.status).to eq(Order::HOLD)
      expect(order.ticket_line_items.map(&:seat_assignment_id)).to match_array(picked.map(&:id))
    end

    it 'rejects a row that lists the same seat twice' do
      seat = locations(picked).first
      expect { run(seating: "#{seat},#{seat}") }.not_to change(TicketOrder, :count)
      expect(seat_assignments.first.reload.order_uuid).to be_nil
    end
  end

  it 'keeps a single counted line item for general admission rows' do
    ga = FactoryBot.create(:general_admission)
    ga_class = ga.production.ticket_classes.where(holds_seats: true).order(:id).first
    csv = <<~CSV
      PerformanceCode,TicketClass,NumberOfTickets,FullName,EmailAddress1
      #{ga.performance_code},#{ga_class.class_code},3,Casey Patron,patron@example.com
    CSV
    described_class.perform(filestore_for(csv).id, ga.production.theater_id,
                            FactoryBot.create(:cash_payment_type).id.to_s, false)

    expect(TicketOrder.last.ticket_line_items.map { |li| [li.ticket_count, li.seat_assignment_id] }).to eq([[3, nil]])
  end
end
