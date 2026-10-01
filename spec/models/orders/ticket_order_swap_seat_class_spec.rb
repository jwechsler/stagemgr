require 'rails_helper'
require 'stripe_mock'

# A class swap (pass redemption at PROCESSED, ticket-class special offer,
# TicketOrder.reassign_payments) replaces a per-seat TicketLineItem with one of
# another class. The replacement must keep the seat (seat_assignment_id) and
# the seat must take the replacement's class, so seat and line item agree:
# the admin order form rebuilds each reserved seat's line item from the seat's
# ticket_class_id, and the print payload falls back to class matching.
#
# Regression for order 337674: a GEN seat paid by membership printed with a
# BLANK seat because the MEMBER line item lost its seat at redemption.
RSpec.describe 'TicketOrder class swaps move the seat and its class to the new line item' do
  include_context 'auto-fulfilling print service'

  before { StripeMock.start }
  after  { StripeMock.stop }

  def pass_ticket_class_for(tkt_order, code, price: 0.00)
    production = tkt_order.performance.production
    tc = production.ticket_classes.detect { |c| c.class_code == code } ||
         FactoryBot.create(:ticket_class, class_code: code, class_name: 'Pass Ticket',
                                          ticket_price: price, web_visible: false, software_managed: true,
                                          production: production, auto_attach: true)
    TicketClassAllocation.find_or_initialize_by(performance: tkt_order.performance, ticket_class: tc).update!(available: true)
    production.ticket_classes.reload
    tkt_order.performance.ticket_class_allocations.reload
    tc
  end

  def orphan_seat_rows
    LineItem.where(order_id: nil).where.not(seat_assignment_id: nil)
  end

  def printed_tickets(tkt_order)
    TicketOrder.find(tkt_order.id).send(:build_tktprint_payload, 'batch', 1)[:tickets_attributes]
  end

  # The public checkout shape: the patron holds one seat as a priced, web
  # visible class and the per-seat line item is built from the form.
  def public_order_with_one_seat
    o = FactoryBot.build(:ticket_order, performance: FactoryBot.create(:reserved_seating),
                                        address: FactoryBot.create(:address), status: Order::NEW)
    seat_class = o.performance.ticket_class_allocations.select(&:available).map(&:ticket_class)
                  .detect { |tc| tc.ticket_price.positive? && !tc.software_managed? }
    SeatAssignment.available_seat_assignments(o.performance)
    seat = o.performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE).order(:id).first
    seat.update!(status: SeatAssignment::TEMPORARY, order_uuid: o.uuid, ticket_class_id: seat_class.id)
    o.ticket_line_items.build(ticket_class: seat_class, ticket_count: 1, seat_assignment_id: seat.id)
    [o, seat, seat_class]
  end

  describe 'membership checkout of one reserved seat (order 337674 shape)' do
    let(:setup) do
      o, seat, seat_class = public_order_with_one_seat
      offer = FactoryBot.create(:membership_offer, use_ticket_class_code: 'MEMBER')
      membership = FactoryBot.create(:membership, address: o.address, membership_offer: offer)
      # Priced like the seat so the pre-charge balance check passes before the swap.
      pass_class = pass_ticket_class_for(o, 'MEMBER', price: seat_class.ticket_price)
      o.member_code = membership.member_code
      o.payment_type = FactoryBot.create(:membership_payment_type)
      o.transition_to!(Order::PROCESSED)
      { order: o, seat: seat, seat_class: seat_class, pass_class: pass_class }
    end

    it 'leaves the order PROCESSED with one member line item holding the seat' do
      o = setup[:order]
      tlis = TicketLineItem.where(order_id: o.id)

      expect(o.reload.status).to eq(Order::PROCESSED)
      expect(tlis.map(&:seat_assignment_id)).to eq([setup[:seat].id])
      expect(tlis.map(&:ticket_class_id)).to eq([setup[:pass_class].id])
      expect(orphan_seat_rows).to be_empty
    end

    it 'gives the seat the member class so seat and line item agree' do
      setup
      seat = setup[:seat].reload

      expect(seat.status).to eq(SeatAssignment::ASSIGNED)
      expect(seat.ticket_class_id).to eq(setup[:pass_class].id)
    end

    it 'prints the ticket with its seat location' do
      setup
      location = setup[:seat].reload.seat.location

      expect(printed_tickets(setup[:order])).to eq([{ ticket_class: 'MEMBER', seat: location }])
    end

    it 'keeps the member class when the admin form resubmits the seat rows' do
      o = TicketOrder.find(setup[:order].id)
      seat = setup[:seat].reload
      tli = o.ticket_line_items.first
      # admin/ticket_orders/_ticket_line_item_table + build_reserved_seat_row:
      # each reserved seat's line item is posted with the seat's class.
      o.update!(ticket_line_items_attributes: {
                  seat.id.to_s => { id: tli.id, ticket_class_id: seat.ticket_class_id,
                                    ticket_count: 1, seat_assignment_id: seat.id }
                })

      expect(tli.reload.ticket_class_id).to eq(setup[:pass_class].id)
    end
  end

  describe 'flex pass redemption on a persisted two-seat order' do
    it 'reclasses every seat to the pass class' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
      order.ticket_line_items.to_a.each(&:destroy)
      order.seats.each do |sa|
        order.ticket_line_items.create!(ticket_class_id: sa.ticket_class_id, ticket_count: 1,
                                        seat_assignment_id: sa.id)
      end
      order.reload
      flex_pass = FactoryBot.create(:flex_pass_order).flex_pass
      pass_class = pass_ticket_class_for(order, flex_pass.flex_pass_offer.use_ticket_class_code)
      order.flex_pass_code = flex_pass.code
      order.payment_type = FactoryBot.create(:flex_pass_payment_type)
      order.payments << FactoryBot.build(:flex_pass_payment, number_of_tickets: order.number_of_tickets,
                                                             flex_pass: flex_pass, amount: 0)
      order.status = Order::PROCESSED
      order.save!

      expect(order.seats.reload.map(&:ticket_class_id).uniq).to eq([pass_class.id])
      locations = order.seats.map { |sa| sa.seat.location }
      expect(printed_tickets(order).pluck(:seat)).to match_array(locations)
    end
  end

  describe 'a ticket-class special offer' do
    it 'reclasses the seats it swaps' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
      order.ticket_line_items.to_a.each(&:destroy)
      order.seats.each do |sa|
        order.ticket_line_items.create!(ticket_class_id: sa.ticket_class_id, ticket_count: 1,
                                        seat_assignment_id: sa.id)
      end
      order.reload
      swap = FactoryBot.create(:ticket_class, production: order.performance.production, class_code: 'SWAP',
                                              class_name: 'Swapped', ticket_price: 1.00, ticket_type: 'Fixed')
      offer = TicketClassSpecialOffer.create!(code: 'SWAPSEATS', change_ticket_class_code: 'SWAP',
                                              status: SpecialOffer::ACTIVE)

      offer.apply_to_order(order)
      order.save!(validate: false)

      expect(order.seats.reload.map(&:ticket_class_id).uniq).to eq([swap.id])
      expect(order.seats.map { |sa| sa.ticket_line_item&.id }).to all(be_present)
    end
  end

  describe 'TicketOrder#replace_ticket_line_item' do
    it 'leaves seats alone when the replaced line item held none' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
      old_li = order.ticket_line_items.first
      seat_classes = order.seats.map(&:ticket_class_id)
      swap = FactoryBot.create(:ticket_class, production: order.performance.production, class_code: 'SWAP2',
                                              class_name: 'Swapped', ticket_price: 1.00, ticket_type: 'Fixed')

      order.replace_ticket_line_item(old_li, TicketLineItem.new(ticket_class: swap,
                                                                ticket_count: old_li.ticket_count))

      expect(order.seats.reload.map(&:ticket_class_id)).to eq(seat_classes)
    end
  end
end
