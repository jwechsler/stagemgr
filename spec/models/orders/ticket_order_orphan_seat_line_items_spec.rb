require 'rails_helper'
require 'stripe_mock'

# Regression coverage for `Duplicate entry '<sa_id>' for key
# 'line_items.index_line_items_on_seat_assignment_id'` on order submit.
#
# Class swaps (pass redemption at PROCESSED, ticket-class special offers) used
# to remove the replaced TicketLineItem with has_many#delete. That nullifies
# order_id but leaves seat_assignment_id set, so the orphan row kept the seat's
# unique FK forever and the next buyer of that seat could not save.
RSpec.describe 'TicketOrder class swaps keep the per-seat line item pairing' do
  include_context 'auto-fulfilling print service'

  before { StripeMock.start }
  after  { StripeMock.stop }

  let(:order) do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
    link_tlis_to_seats!(o)
    o.reload
  end

  # The factory builds one aggregated TLI; checkout builds one TLI per seat.
  def link_tlis_to_seats!(tkt_order)
    tkt_order.ticket_line_items.to_a.each(&:destroy)
    tkt_order.seats.each do |sa|
      tkt_order.ticket_line_items.create!(ticket_class_id: sa.ticket_class_id, ticket_count: 1,
                                          seat_assignment_id: sa.id)
    end
  end

  def pass_ticket_class_for(tkt_order, code)
    production = tkt_order.performance.production
    tc = production.ticket_classes.detect { |c| c.class_code == code } ||
         FactoryBot.create(:ticket_class, class_code: code, class_name: 'Pass Ticket',
                                          ticket_price: 0.00, web_visible: false, software_managed: true,
                                          production: production, auto_attach: true)
    TicketClassAllocation.find_or_initialize_by(performance: tkt_order.performance, ticket_class: tc).update!(available: true)
    production.ticket_classes.reload
    tkt_order.performance.ticket_class_allocations.reload
    tc
  end

  def orphan_seat_rows
    LineItem.where(order_id: nil).where.not(seat_assignment_id: nil)
  end

  def redeem_membership!(tkt_order)
    membership = FactoryBot.create(:membership, address: tkt_order.address)
    pass_class = pass_ticket_class_for(tkt_order, membership.membership_offer.use_ticket_class_code)
    tkt_order.member_code = membership.member_code
    tkt_order.payment_type = FactoryBot.create(:membership_payment_type)
    tkt_order.payments << FactoryBot.build(:membership_payment, number_of_tickets: tkt_order.number_of_tickets,
                                                                membership: membership, amount: 0)
    tkt_order.status = Order::PROCESSED
    tkt_order.save!
    pass_class
  end

  describe 'membership redemption on a persisted reserved-seat order' do
    it 'keeps one line item per seat, each carrying its seat_assignment_id' do
      seat_ids = order.seats.map(&:id)
      pass_class = redeem_membership!(order)

      tlis = TicketLineItem.where(order_id: order.id)
      expect(tlis.map(&:seat_assignment_id)).to match_array(seat_ids)
      expect(tlis.map(&:ticket_class_id).uniq).to eq([pass_class.id])
      expect(tlis.sum(:ticket_count)).to eq(seat_ids.size)
    end

    it 'leaves no orphaned line items holding a seat' do
      redeem_membership!(order)

      expect(orphan_seat_rows).to be_empty
    end

    it 'lets a later order claim a released seat without a duplicate-key error' do
      redeem_membership!(order)
      seat = order.seats.first
      ticket_class = seat.ticket_class
      order.refund!

      new_order = FactoryBot.build(:ticket_order, performance: order.performance, status: Order::NEW)
      new_order.save!(validate: false)
      SeatAssignment.find(seat.id).update!(order_uuid: new_order.uuid, status: SeatAssignment::ASSIGNED,
                                           ticket_class_id: ticket_class.id)

      expect do
        new_order.ticket_line_items.create!(ticket_class: ticket_class, ticket_count: 1,
                                            seat_assignment_id: seat.id)
      end.not_to raise_error
    end
  end

  # The call OrdersHelper#process_order makes for both the public checkout and
  # the admin order form: NEW saves as PROCESSING first, so the pass swap at
  # PROCESSED always runs against persisted per-seat line items.
  describe 'checkout with a membership (transition_to! PROCESSED from NEW)' do
    it 'keeps the seat pairing and leaves no orphans' do
      o = FactoryBot.build(:ticket_order, performance: FactoryBot.create(:reserved_seating),
                                          address: FactoryBot.create(:address), status: Order::NEW)
      offer = FactoryBot.create(:membership_offer, use_ticket_class_code: 'MEMBER')
      membership = FactoryBot.create(:membership, address: o.address, membership_offer: offer)
      seat_class = o.performance.ticket_class_allocations.select(&:available).map(&:ticket_class)
                    .detect { |tc| tc.ticket_price.positive? && !tc.software_managed? }
      SeatAssignment.available_seat_assignments(o.performance)
      seats = o.performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE).order(:id).first(2)
      expect(seats.size).to eq(2)
      seats.each do |sa|
        sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: o.uuid, ticket_class_id: seat_class.id)
        o.ticket_line_items.build(ticket_class: seat_class, ticket_count: 1, seat_assignment_id: sa.id)
      end
      # Priced like the seat so the pre-charge balance check passes before
      # the swap (the payment is sized at min(seat, pass) per ticket).
      pass_class = pass_ticket_class_for(o, 'MEMBER')
      pass_class.update!(ticket_price: seat_class.ticket_price)
      o.member_code = membership.member_code
      o.payment_type = FactoryBot.create(:membership_payment_type)

      o.transition_to!(Order::PROCESSED)

      tlis = TicketLineItem.where(order_id: o.id)
      expect(o.reload.status).to eq(Order::PROCESSED)
      expect(tlis.map(&:seat_assignment_id)).to match_array(seats.map(&:id))
      expect(tlis.map(&:ticket_class_id).uniq).to eq([pass_class.id])
      expect(orphan_seat_rows).to be_empty
    end
  end

  describe 'flex pass redemption on a persisted reserved-seat order' do
    it 'keeps each seat paired with its swapped line item' do
      flex_pass = FactoryBot.create(:flex_pass_order).flex_pass
      pass_class = pass_ticket_class_for(order, flex_pass.flex_pass_offer.use_ticket_class_code)
      seat_ids = order.seats.map(&:id)
      order.flex_pass_code = flex_pass.code
      order.payment_type = FactoryBot.create(:flex_pass_payment_type)
      order.payments << FactoryBot.build(:flex_pass_payment, number_of_tickets: order.number_of_tickets,
                                                             flex_pass: flex_pass, amount: 0)
      order.status = Order::PROCESSED
      order.save!

      tlis = TicketLineItem.where(order_id: order.id)
      expect(tlis.map(&:seat_assignment_id)).to match_array(seat_ids)
      expect(tlis.map(&:ticket_class_id).uniq).to eq([pass_class.id])
      expect(orphan_seat_rows).to be_empty
    end
  end

  describe 'a ticket-class special offer on a persisted reserved-seat order' do
    it 'moves each seat onto its replacement line item and orphans nothing' do
      FactoryBot.create(:ticket_class, production: order.performance.production, class_code: 'SWAP',
                                       class_name: 'Swapped', ticket_price: 1.00, ticket_type: 'Fixed')
      offer = TicketClassSpecialOffer.create!(code: 'SWAPSEATS', change_ticket_class_code: 'SWAP',
                                              status: SpecialOffer::ACTIVE)
      seat_ids = order.seats.map(&:id)

      offer.apply_to_order(order)
      order.save!(validate: false)

      tlis = TicketLineItem.where(order_id: order.id)
      expect(tlis.map(&:seat_assignment_id)).to match_array(seat_ids)
      expect(tlis.map { |t| t.ticket_class.class_code }.uniq).to eq(['SWAP'])
      expect(orphan_seat_rows).to be_empty
    end
  end

  describe 'removing a zero-count line item' do
    it 'destroys the row instead of orphaning it' do
      tli = order.ticket_line_items.first
      tli.update_columns(ticket_count: 0)
      order.reload.save!(validate: false)

      expect(LineItem.exists?(tli.id)).to be(false)
    end
  end
end
