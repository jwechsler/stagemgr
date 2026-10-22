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

  # Regression for a box-office order of 2 x GENPREV20 ($20) paid with a
  # 10-show Flex Pass whose FLEX20 class is $22.50: the pass payment covered
  # $40 (the lesser price per ticket) but the swapped-in FLEX20 line items
  # carried $45, so the order could not be processed.
  describe 'pass redemption pricing' do
    let(:regular_price) { BigDecimal('20.00') }
    let(:dearer_pass_price) { BigDecimal('22.50') }
    let(:cheaper_pass_price) { BigDecimal('15.00') }

    def regular_ticket_class_for(tkt_order)
      production = tkt_order.performance.production
      tc = FactoryBot.create(:ticket_class, class_code: 'GENPREV20', class_name: 'Preview',
                                            ticket_price: regular_price, production: production)
      TicketClassAllocation.find_or_initialize_by(performance: tkt_order.performance, ticket_class: tc).update!(available: true)
      production.ticket_classes.reload
      tkt_order.performance.ticket_class_allocations.reload
      tc
    end

    def new_flex_pass_order(performance)
      o = FactoryBot.build(:ticket_order, performance: performance, address: FactoryBot.create(:address),
                                          status: Order::NEW)
      flex_pass = FactoryBot.create(:flex_pass_order,
                                    flex_pass_offer: FactoryBot.create(:flex_pass_offer,
                                                                       use_ticket_class_code: 'FLEX20')).flex_pass
      o.flex_pass_code = flex_pass.code
      o.payment_type = FactoryBot.create(:flex_pass_payment_type)
      o
    end

    # Two regular GA tickets on one line item, redeemed against a pass class at pass_price.
    def ga_order(pass_price:)
      o = new_flex_pass_order(FactoryBot.create(:general_admission))
      regular = regular_ticket_class_for(o)
      pass_class = pass_ticket_class_for(o, 'FLEX20', price: pass_price)
      o.ticket_line_items.build(ticket_class: regular, ticket_count: 2)
      { order: o, regular: regular, pass_class: pass_class }
    end

    # Two regular reserved seats, one line item each (the public/box office shape).
    def reserved_order(pass_price:)
      o = new_flex_pass_order(FactoryBot.create(:reserved_seating))
      regular = regular_ticket_class_for(o)
      pass_class = pass_ticket_class_for(o, 'FLEX20', price: pass_price)
      SeatAssignment.available_seat_assignments(o.performance)
      seats = o.performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE).order(:id).first(2)
      seats.each do |seat|
        seat.update!(status: SeatAssignment::TEMPORARY, order_uuid: o.uuid, ticket_class_id: regular.id)
        o.ticket_line_items.build(ticket_class: regular, ticket_count: 1, seat_assignment_id: seat.id)
      end
      { order: o, regular: regular, pass_class: pass_class, seats: seats }
    end

    def saved_line_items(tkt_order)
      TicketLineItem.where(order_id: tkt_order.id).to_a
    end

    it 'charges a GA order the regular price when the pass class costs more' do
      setup = ga_order(pass_price: dearer_pass_price)
      o = setup[:order]

      o.transition_to!(Order::PROCESSED)

      tlis = saved_line_items(o)
      expect(o.reload.status).to eq(Order::PROCESSED)
      expect(tlis.map(&:ticket_class_id)).to eq([setup[:pass_class].id])
      expect(tlis.map(&:price_override)).to eq([regular_price])
      expect(tlis.sum(&:total)).to eq(2 * regular_price)
      expect(o.flex_pass_payments.sum(&:amount)).to eq(2 * regular_price)
    end

    it 'charges a reserved order the regular price and gives the seats the same override' do
      setup = reserved_order(pass_price: dearer_pass_price)
      o = setup[:order]

      o.transition_to!(Order::PROCESSED)

      tlis = saved_line_items(o)
      expect(o.reload.status).to eq(Order::PROCESSED)
      expect(tlis.map(&:ticket_class_id).uniq).to eq([setup[:pass_class].id])
      expect(tlis.map(&:price_override)).to eq([regular_price, regular_price])
      expect(tlis.sum(&:total)).to eq(2 * regular_price)
      expect(o.flex_pass_payments.sum(&:amount)).to eq(2 * regular_price)
      seats = SeatAssignment.where(id: setup[:seats].map(&:id))
      expect(seats.map(&:ticket_class_id).uniq).to eq([setup[:pass_class].id])
      expect(seats.map(&:price_override)).to eq([regular_price, regular_price])
    end

    it 'prices at the pass class price, with no override, when the pass class is cheaper' do
      setup = reserved_order(pass_price: cheaper_pass_price)
      o = setup[:order]

      o.transition_to!(Order::PROCESSED)

      tlis = saved_line_items(o)
      expect(tlis.map(&:price_override)).to eq([nil, nil])
      expect(tlis.sum(&:total)).to eq(2 * cheaper_pass_price)
      expect(o.flex_pass_payments.sum(&:amount)).to eq(2 * cheaper_pass_price)
      expect(SeatAssignment.where(id: setup[:seats].map(&:id)).map(&:price_override)).to eq([nil, nil])
    end

    it 'keeps the redemption price when the admin form resubmits the seat rows' do
      setup = reserved_order(pass_price: dearer_pass_price)
      setup[:order].transition_to!(Order::PROCESSED)
      o = TicketOrder.find(setup[:order].id)
      # admin/ticket_orders/_ticket_line_item_table posts each seat's class and override.
      rows = o.seats.to_h do |seat|
        [seat.id.to_s, { id: seat.ticket_line_item.id, ticket_class_id: seat.ticket_class_id, ticket_count: 1,
                         seat_assignment_id: seat.id, price_override: seat.price_override }]
      end

      o.update!(ticket_line_items_attributes: rows)

      expect(saved_line_items(o).map(&:price_override)).to eq([regular_price, regular_price])
      expect(o.reload.total_due).to eq(o.total_paid)
    end

    it 'still strips an admin override on a fixed class of an order not paid with a pass' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)
      tli = order.ticket_line_items.first

      tli.update!(price_override: 1)

      expect(tli.reload.price_override).to be_nil
    end
  end

  # A failed transition hands the form back the line items the user
  # submitted, not the pass class ones the redemption swapped in.
  #
  # Runs outside the per-example transaction (:concurrent_db), as the box
  # office does: inside it, transition_to!'s transaction is only a savepoint,
  # and Rails restores the new_record/destroyed/id state of rolled-back
  # records saved more than once only on a real rollback.
  describe 'a failed pass redemption', :concurrent_db do
    self.use_transactional_tests = false

    include ConcurrentDbSnapshot

    around { |example| with_db_snapshot { example.run } }

    # Fails after the swap, before the charge (as the unbalanced order did).
    def fail_a_check(tkt_order)
      allow(tkt_order).to receive(:seat_holds_current?).and_return(false)
    end

    # Fails after the swapped line items were written and the old ones deleted.
    def fail_the_charge(tkt_order)
      allow(tkt_order.payment_type).to receive(:charge!).and_raise(StandardError, 'pass declined')
    end

    def flex_pass_for_order(tkt_order)
      # An offer with no theater, so the pass is good for any production.
      flex_pass = FactoryBot.create(:flex_pass_order, flex_pass_offer: FactoryBot.create(:flex_pass_offer)).flex_pass
      pass_ticket_class_for(tkt_order, flex_pass.flex_pass_offer.use_ticket_class_code)
      tkt_order.flex_pass_code = flex_pass.code
      tkt_order.payment_type = FactoryBot.create(:flex_pass_payment_type)
    end

    it 'restores the unsaved line items of a new order, which then processes' do
      o = FactoryBot.build(:ticket_order, performance: FactoryBot.create(:general_admission),
                                          address: FactoryBot.create(:address), status: Order::NEW)
      regular = o.performance.ticket_class_allocations.select(&:available).map(&:ticket_class)
                 .detect { |tc| tc.ticket_price.positive? }
      submitted = o.ticket_line_items.build(ticket_class: regular, ticket_count: 2)
      flex_pass_for_order(o)
      fail_a_check(o)

      expect { o.transition_to!(Order::PROCESSED) }.to raise_error(RuntimeError, /unsuccessful/)

      expect(o.status).to eq(Order::NEW)
      expect(o.id).to be_nil
      expect(o.ticket_line_items.to_a).to eq([submitted])
      expect(submitted).to be_new_record
      expect(submitted.ticket_class).to eq(regular)

      RSpec::Mocks.space.proxy_for(o).reset
      o.transition_to!(Order::PROCESSED)
      expect(o.reload.status).to eq(Order::PROCESSED)
    end

    it 'restores the edited line items of a persisted order and its seats' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating)
      order.ticket_line_items.to_a.each(&:destroy)
      order.seats.each do |sa|
        order.ticket_line_items.create!(ticket_class_id: sa.ticket_class_id, ticket_count: 1,
                                        seat_assignment_id: sa.id)
      end
      order.reload
      regular_class_ids = order.seats.map(&:ticket_class_id)
      submitted = order.ticket_line_items.to_a
      submitted.first.internal_description = 'unsaved edit'
      flex_pass_for_order(order)
      fail_the_charge(order)

      expect { order.transition_to!(Order::PROCESSED) }.to raise_error(StandardError, 'pass declined')

      expect(order.ticket_line_items.to_a).to eq(submitted)
      expect(submitted).to all(be_persisted)
      expect(submitted.map(&:destroyed?)).to all(be(false))
      expect(submitted.map(&:ticket_class_id)).to eq(regular_class_ids)
      expect(submitted.first.internal_description).to eq('unsaved edit')
      expect(order.seats.map(&:ticket_class_id)).to eq(regular_class_ids)
      expect(TicketLineItem.where(order_id: order.id).pluck(:id)).to match_array(submitted.map(&:id))
    end
  end
end
