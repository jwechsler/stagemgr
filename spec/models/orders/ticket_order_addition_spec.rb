require 'rails_helper'

# Add to Order: an addition is its own TicketOrder (merge_target_id, in memory
# only) processed through the normal pipeline, then merged into the processed
# order it was added to and deleted. See TicketOrderAddition and
# TicketOrderMergeable.
RSpec.describe TicketOrderAddition do
  let(:show_date) { Date.current + 7.days }

  before do
    allow(Resque).to receive(:enqueue)
    allow_any_instance_of(TicketOrder).to receive(:resend_confirmation!)
  end

  def allocate(ticket_class, performance, ticket_limit: nil)
    tca = TicketClassAllocation.find_or_initialize_by(performance: performance, ticket_class: ticket_class)
    tca.update!(available: true, ticket_limit: ticket_limit)
    performance.ticket_class_allocations.reload
    tca
  end

  # The ticket_class factory finds by class_code alone, so every code is unique.
  def addon_class(production, performance, price: 5, **attrs)
    tc = FactoryBot.create(:ticket_class, production: production, holds_seats: false, ticket_price: price,
                                          class_code: "ADD#{SecureRandom.hex(3).upcase}", class_name: 'Captioning tablet',
                                          **attrs)
    allocate(tc, performance)
    tc
  end

  let(:card_details) do
    { credit_card_type: 'Visa', credit_card_number: '4111111111111111', credit_card_expiration_month: '12',
      credit_card_expiration_year: (Date.current.year + 2).to_s, credit_card_verification_number: '123' }
  end

  def stub_gateway(success: true)
    gateway = double('gateway')
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    response = double('response', success?: success, authorization: success ? 'ch_add' : nil,
                                  params: {}, message: success ? 'OK' : 'Your card was declined.')
    allow(gateway).to receive(:purchase).and_return(response)
    gateway
  end

  # The addition's row, if one was left behind. An addition is found by its
  # uuid: no row records the order it was added to.
  def addition_rows(addition)
    TicketOrder.where(uuid: addition.uuid)
  end

  # What the box-office order page does on "Place Order" for an addition.
  def place_addition(target, payment_type:, lines: [], seats: [], send_confirmation: true, addition: nil, **attrs)
    addition ||= described_class.build_for(target)
    addition.payment_type = payment_type
    lines.each { |tc, count| addition.ticket_line_items << TicketLineItem.new(ticket_class: tc, ticket_count: count) }
    seats.each do |sa|
      addition.ticket_line_items << TicketLineItem.new(ticket_class_id: sa.ticket_class_id, ticket_count: 1,
                                                       seat_assignment_id: sa.id)
    end
    attrs.each { |name, value| addition.public_send("#{name}=", value) }
    addition.box_office_sale = true
    addition.send_merge_confirmation = send_confirmation
    addition.transition_to!(Order::PROCESSED)
    addition
  end

  describe '.addable?' do
    let(:target) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }

    before { target.performance.update_columns(performance_date: show_date) }

    it 'accepts a processed order for an upcoming performance' do
      expect(described_class.addable?(target)).to be true
    end

    it 'refuses fulfilled, unclaimed, refunded and cancelled orders' do
      [Order::FULFILLED, Order::UNCLAIMED, Order::REFUNDED, Order::CANCELED].each do |status|
        target.update_column(:status, status)
        expect(described_class.addable?(target)).to be false
      end
    end

    it 'accepts a processed order after its performance (post-show clean-up)' do
      target.performance.update_columns(performance_date: Date.current - 3.days)
      expect(described_class.addable?(target.reload)).to be true
    end

    it 'refuses while an exchange is replacing the order' do
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: target.performance)
                .update_columns(status: Order::EXCHANGING, exchange_source_id: target.id)
      expect(described_class.addable?(target)).to be false
    end
  end

  describe 'general admission' do
    let(:production) { FactoryBot.create(:production, capacity: 10) }
    let(:performance) do
      FactoryBot.create(:general_admission, production: production, performance_date: show_date,
                                            performance_time: Time.parse('19:00'))
    end
    let(:target) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance) }
    let(:tablet) { addon_class(production, performance, ticketing_fee: 1) }
    let(:cash) { FactoryBot.create(:cash_payment_type) }

    describe '.build_for' do
      it "starts a new order on the same performance and the order's own address record, with its own uuid" do
        addition = described_class.build_for(target)

        expect(addition).to be_new_record
        expect(addition.merge_target).to eq(target)
        expect(addition.performance).to eq(target.performance)
        expect(addition.address).to equal(target.address)
        expect(addition.uuid).to be_present
        expect(addition.uuid).not_to eq(target.uuid)
        expect(addition.do_not_create_tasks).to be true
      end

      it 'adds no default per-order service fees' do
        template = FactoryBot.create(:service_item_template)
        production.update!(override_service_items: template.name)
        expect(production.service_item_templates_new).to include(template)

        expect(described_class.build_for(target).service_line_items).to be_empty
      end
    end

    it 'merges a cash-paid add-on into the order and deletes the emptied addition' do
      paid_before = target.total_paid
      addition = place_addition(target, payment_type: cash, lines: [[tablet, 1]])

      target.reload
      expect(addition).to be_addition_placed
      expect(TicketOrder.exists?(addition.id)).to be false
      expect(LineItem.where(order_id: addition.id)).to be_empty
      expect(Payment.unscoped.where(order_id: addition.id)).to be_empty
      expect(OrderTask.where(order_id: addition.id)).to be_empty
      expect(target.status).to eq(Order::PROCESSED)
      expect(target.ticket_line_items.map(&:ticket_class)).to include(tablet)
      expect(target.total_paid - paid_before).to eq(5)
      expect(target.payments.map(&:class)).to include(CashPayment)
      expect(target.total_due).to eq(target.total_paid)
    end

    it "keeps the deleted addition's own audit trail" do
      addition = place_addition(target, payment_type: cash, lines: [[tablet, 1]])

      expect(Audited::Audit.where(auditable_type: 'Order', auditable_id: addition.id).pluck(:action))
        .to include('create', 'destroy')
    end

    it "appends the addition's notes to the order's own notes" do
      target.update_columns(notes: 'Patron uses a wheelchair')
      place_addition(target, payment_type: cash, lines: [[tablet, 1]], notes: 'Tablet requested by phone')

      expect(target.reload.notes).to eq("Patron uses a wheelchair\nTablet requested by phone")
    end

    it 'leaves the order notes alone when the addition has none' do
      target.update_columns(notes: 'Patron uses a wheelchair')
      place_addition(target, payment_type: cash, lines: [[tablet, 1]])

      expect(target.reload.notes).to eq('Patron uses a wheelchair')
    end

    it 'carries the per-ticket ticketing fee onto the order (it is part of the face value)' do
      fee_before = target.ticketing_fee
      place_addition(target, payment_type: cash, lines: [[tablet, 2]])

      expect(target.reload.ticketing_fee - fee_before).to eq(2)
    end

    it 'charges a card under the addition\'s own uuid' do
      gateway = stub_gateway
      addition = place_addition(target, payment_type: FactoryBot.create(:credit_card_payment_type),
                                        lines: [[tablet, 1]], **card_details)

      expect(gateway).to have_received(:purchase)
        .with(500, anything, hash_including(idempotency_key: addition.uuid))
      expect(target.reload.payments.grep(CreditCardPayment).map(&:transaction_id)).to include('ch_add')
      expect(target.payments.grep(CreditCardPayment).size).to eq(2)
    end

    it "names the addition's card charge in the order's audit trail" do
      stub_gateway
      addition = place_addition(target, payment_type: FactoryBot.create(:credit_card_payment_type),
                                        lines: [[tablet, 1]], **card_details)

      expect(target.audits.reload.last.comment)
        .to eq("Added from order ##{addition.id} (card charge ch_add): 1× Captioning tablet")
    end

    it 'leaves no addition behind and the order unchanged when the card is declined' do
      target
      before = [target.reload.ticket_line_items.pluck(:id), target.payments.pluck(:id), target.updated_at]
      stub_gateway(success: false)
      tablet
      addition = described_class.build_for(target)

      expect do
        place_addition(target, addition: addition, payment_type: FactoryBot.create(:credit_card_payment_type),
                               lines: [[tablet, 1]], **card_details)
      end.to raise_error(CannotProcessPayment)
      expect(addition).not_to be_addition_placed
      expect(addition_rows(addition)).not_to exist
      target.reload
      expect([target.ticket_line_items.pluck(:id), target.payments.pluck(:id), target.updated_at]).to eq(before)
    end

    it 'keeps the address record untouched and creates no copy or address-of-record task' do
      target
      address_before = target.address.reload.attributes

      expect do
        addition = place_addition(target, payment_type: cash, lines: [[tablet, 1]])
        expect(addition.address_id).to eq(target.address_id)
        expect(LinkToAddressOfRecordTask.where(order_id: addition.id)).not_to exist
      end.not_to change(Address, :count)
      expect(target.address.reload.attributes.except('updated_at')).to eq(address_before.except('updated_at'))
    end

    it 'records the merge in the order\'s audit trail' do
      addition = place_addition(target, payment_type: cash, lines: [[tablet, 2]])

      expect(target.audits.reload.last.comment).to eq("Added from order ##{addition.id}: 2× Captioning tablet")
    end

    it 'queues one house-count refresh for the order once the merge has committed' do
      target
      expect(Resque).to receive(:enqueue).with(CalculateHouseCountsJob, performance.id).once

      place_addition(target, payment_type: cash, lines: [[tablet, 1]])
    end

    describe 'confirmation email' do
      it 'resends the order\'s confirmation once by default' do
        target
        expect_any_instance_of(TicketOrder).to receive(:resend_confirmation!).once

        place_addition(target, payment_type: cash, lines: [[tablet, 1]])
      end

      it 'sends nothing when staff suppress it' do
        target
        expect_any_instance_of(TicketOrder).not_to receive(:resend_confirmation!)

        place_addition(target, payment_type: cash, lines: [[tablet, 1]], send_confirmation: false)
      end

      it 'queues no receipt, reminder or mailing-list task on the addition' do
        addition = place_addition(target, payment_type: cash, lines: [[tablet, 1]], add_to_email_list: '1')

        expect(OrderTask.where(order_id: addition.id)).to be_empty
        expect(MyEmmaTask.where(order_id: addition.id)).to be_empty
      end
    end

    it 'refuses a special offer or discount code' do
      expect do
        place_addition(target, payment_type: cash, lines: [[tablet, 1]], special_offer_code: 'HALFOFF')
      end.to raise_error(ActiveRecord::RecordInvalid, /Special offers and discount codes do not apply/)
    end

    it 'refuses an addition that the order\'s own special offer would re-price' do
      offer_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance, payment_type: cash)
      offer_order.create_special_offer_line_item!(special_offer: FactoryBot.create(:percent_off_special_offer, amount: 50))
      offer_order.payments << FactoryBot.create(:cash_payment, order: offer_order, amount: offer_order.total_due)
      offer_order.update!(status: Order::PROCESSED)

      expect do
        place_addition(offer_order.reload, payment_type: cash, lines: [[tablet, 1]])
      end.to raise_error(TicketOrderAddition::Refused, /would also discount these tickets/)
    end

    it 'refuses to hold an addition' do
      addition = described_class.build_for(target)
      addition.payment_type = cash
      addition.ticket_line_items << TicketLineItem.new(ticket_class: tablet, ticket_count: 1)

      expect { addition.transition_to!(Order::HOLD) }.to raise_error(ActiveRecord::RecordInvalid, /can't be Hold/)
    end

    it 'refuses an extra seat when the house is at capacity (normal stock check)' do
      seat_class = target.ticket_line_items.first.ticket_class
      filler = TicketOrder.new(status: Order::NEW, performance: performance, address: FactoryBot.create(:address),
                               payment_type: cash)
      filler.ticket_line_items << TicketLineItem.new(ticket_class: seat_class,
                                                     ticket_count: performance.number_of_seats_left)
      filler.save!

      expect do
        place_addition(target, payment_type: cash, lines: [[seat_class, 1]])
      end.to raise_error(ActiveRecord::RecordInvalid, /remaining|left/)
    end

    it 'adds a GA seat that then counts against the house' do
      seat_class = target.ticket_line_items.first.ticket_class
      held_before = performance.seats_held

      place_addition(target, payment_type: cash, lines: [[seat_class, 1]])

      expect(performance.seats_held).to eq(held_before + 1)
      expect(target.reload.number_of_seats).to eq(3)
    end

    it 'refunds the charge exactly once and leaves no addition behind when the merge fails after payment' do
      target
      gateway = stub_gateway
      allow(gateway).to receive(:refund).and_return(double('refund', success?: true, message: 'OK'))
      allow_any_instance_of(described_class).to receive(:move_rows!).and_raise('database went away')
      addition = described_class.build_for(target)

      expect do
        place_addition(target, addition: addition, payment_type: FactoryBot.create(:credit_card_payment_type),
                               lines: [[tablet, 1]], **card_details)
      end.to raise_error(RuntimeError, 'database went away')
      expect(gateway).to have_received(:purchase).once
      expect(gateway).to have_received(:refund).with(500, 'ch_add', hash_including(note: ChargeAfterChecks::CHARGE_REVERSAL_NOTE)).once
      expect(addition_rows(addition)).not_to exist
      expect(target.ticket_line_items.reload.map(&:ticket_class)).not_to include(tablet)
    end

    # The transition refunds its own charge; the merge's handler must not
    # refund it a second time.
    it 'refunds the charge exactly once when a step after it inside the transition raises' do
      target
      gateway = stub_gateway
      allow(gateway).to receive(:refund).and_return(double('refund', success?: true, message: 'OK'))
      allow_any_instance_of(TicketOrder).to receive(:set_email_confirmation).and_raise('save failed')
      addition = described_class.build_for(target)

      expect do
        place_addition(target, addition: addition, payment_type: FactoryBot.create(:credit_card_payment_type),
                               lines: [[tablet, 1]], **card_details)
      end.to raise_error(RuntimeError, 'save failed')
      expect(gateway).to have_received(:refund).with(500, 'ch_add', anything).once
      expect(addition_rows(addition)).not_to exist
    end

    it 'refuses before charging when the order is no longer processed' do
      gateway = stub_gateway
      addition = described_class.build_for(target)
      target.update_column(:status, Order::FULFILLED)

      expect do
        place_addition(target, addition: addition, payment_type: FactoryBot.create(:credit_card_payment_type),
                               lines: [[tablet, 1]], **card_details)
      end.to raise_error(TicketOrderAddition::Refused, /can no longer be added to/)
      expect(gateway).not_to have_received(:purchase)
      expect(addition_rows(addition)).not_to exist
    end
  end

  describe 'resourced device pool' do
    let(:venue) { FactoryBot.create(:venue) }
    let(:production) { FactoryBot.create(:production, venue: venue, running_time: 120) }
    let(:performance) do
      FactoryBot.create(:performance, production: production, performance_date: show_date,
                                      performance_time: Time.parse("#{show_date} 19:00"))
    end
    let(:resource) { FactoryBot.create(:resourced_ticket_class, quantity: 1, venues: [venue]) }
    let(:shadow) do
      tc = TicketClass.find_or_initialize_by(production_id: production.id, resourced_ticket_class_id: resource.id)
      tc.synced_from_resource = true
      tc.attributes = resource.shadow_attributes
      tc.save!
      allocate(tc, performance)
      tc
    end

    it 'refuses a device once the pool is exhausted (normal resourced stock check)' do
      other = TicketOrder.new(status: Order::PROCESSED, performance: performance, address: FactoryBot.create(:address),
                              payment_type: FactoryBot.create(:cash_payment_type))
      other.ticket_line_items << TicketLineItem.new(ticket_class: shadow, ticket_count: 1)
      other.save!
      target = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance)

      expect do
        place_addition(target, payment_type: FactoryBot.create(:cash_payment_type), lines: [[shadow, 1]])
      end.to raise_error(ActiveRecord::RecordInvalid, /equipment is in use/)
    end
  end

  describe 'reserved seating' do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance) do
      FactoryBot.create(:reserved_seating, production: production, performance_date: show_date,
                                           performance_time: Time.parse('19:00'))
    end
    let(:target) do
      SeatAssignment.available_seat_assignments(performance)
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance)
    end
    let(:seat_class) { target.ticket_line_items.first.ticket_class }

    it 'moves the new seat onto the order and leaves its existing seats alone' do
      existing = target.seats.reload.map { |sa| [sa.id, sa.status, sa.ticket_class_id] }
      # The seat map holds a pick TEMPORARY under the new order's uuid.
      addition = described_class.build_for(target)
      held = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
      held.assign_to_order(addition.uuid, 999, seat_class.id)

      place_addition(target, addition: addition, payment_type: FactoryBot.create(:cash_payment_type), seats: [held])

      held.reload
      expect(TicketOrder.exists?(addition.id)).to be false
      expect(held.status).to eq(SeatAssignment::ASSIGNED)
      expect(held.order_uuid).to eq(target.uuid)
      expect(held.ticket_line_item.order_id).to eq(target.id)
      expect(target.seats.reload.where.not(id: held.id).map { |sa| [sa.id, sa.status, sa.ticket_class_id] })
        .to match_array(existing)
      expect(target.audits.reload.last.comment)
        .to eq("Added from order ##{addition.id}: 1× #{seat_class.class_name} (#{held.seat.location})")
    end
  end

  describe 'reserved seating, failed attempt' do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance) do
      FactoryBot.create(:reserved_seating, production: production, performance_date: show_date,
                                           performance_time: Time.parse('19:00'))
    end
    let(:target) do
      SeatAssignment.available_seat_assignments(performance)
      FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance)
    end

    it 'frees the seats a declined addition held, leaving the order unchanged' do
      seat_class = target.ticket_line_items.first.ticket_class
      stub_gateway(success: false)
      addition = described_class.build_for(target)
      held = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
      held.assign_to_order(addition.uuid, 999, seat_class.id)

      expect do
        place_addition(target, addition: addition, payment_type: FactoryBot.create(:credit_card_payment_type),
                               seats: [held], **card_details)
      end.to raise_error(CannotProcessPayment)
      expect(held.reload.status).to eq(SeatAssignment::TEMPORARY) # the transaction never touched the hold

      described_class.release_holds(addition)

      expect(held.reload.status).to eq(SeatAssignment::AVAILABLE)
      expect(held.order_uuid).to be_nil
      expect(addition_rows(addition)).not_to exist
      expect(target.seats.reload.map(&:status).uniq).to eq([SeatAssignment::ASSIGNED])
    end
  end

  describe 'on a membership-paid order' do
    let(:production) { FactoryBot.create(:production) }
    let(:performance) do
      FactoryBot.create(:general_admission, production: production, performance_date: show_date,
                                            performance_time: Time.parse('19:00'))
    end
    # :paid_with_membership uses a membership whose offer caps it at 2 per performance.
    let(:target) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_membership, performance: performance) }
    let(:membership) { target.membership_payments.first.membership }
    let(:seat_class) { production.ticket_classes.detect { |tc| tc.class_code != 'PASS' && tc.ticket_price.positive? } }

    it 'refuses a seat the membership would pay for over its cap' do
      expect(membership.membership_offer.tickets_per_performance).to eq(2)

      expect do
        place_addition(target, payment_type: FactoryBot.create(:membership_payment_type),
                               lines: [[seat_class, 1]], member_code: membership.member_code)
      end.to raise_error(Exceptions::TooManyTicketsForMembership, /not allowed for this membership/)
      expect(target.ticket_line_items.reload.sum(:ticket_count)).to eq(2)
    end

    it 'adds a card-paid extra seat, leaving the order with both payments' do
      stub_gateway
      place_addition(target, payment_type: FactoryBot.create(:credit_card_payment_type),
                             lines: [[seat_class, 1]], **card_details)

      target.reload
      expect(target.ticket_line_items.sum(:ticket_count)).to eq(3)
      expect(target.payments.map(&:class)).to include(MembershipPayment, CreditCardPayment)
      expect { membership.verify_applicable_for(target) }.not_to raise_error
      expect(target).to be_valid
    end

    it 'can no longer be exchanged once it holds a membership and a card payment, but stays sold and refundable' do
      expect(target).to be_exchangeable
      stub_gateway
      place_addition(target, payment_type: FactoryBot.create(:credit_card_payment_type),
                             lines: [[seat_class, 1]], **card_details)

      target.reload
      expect(target).to be_paid_with_pass_and_currency
      expect(target).not_to be_exchangeable
      expect(target).to be_sold
      expect(target).to be_refundable
    end
  end

  # Order#refund! on an order that gained a second payment through a merge.
  describe 'refunding a merged order' do
    let(:production) { FactoryBot.create(:production) }
    let(:performance) do
      FactoryBot.create(:general_admission, production: production, performance_date: show_date,
                                            performance_time: Time.parse('19:00'))
    end
    let(:seat_class) { production.ticket_classes.detect { |tc| tc.class_code != 'PASS' && tc.ticket_price.positive? } }
    let(:gateway) do
      double('gateway').tap do |g|
        allow(PaymentProcessing).to receive(:gateway).and_return(g)
        allow(g).to receive(:purchase)
          .and_return(double('charge', success?: true, authorization: 'ch_addition', params: {}, message: 'OK'))
        allow(g).to receive(:refund)
          .and_return(double('refund', success?: true, authorization: 're_1', params: {}, message: 'OK'))
      end
    end

    def add_card_paid_seat(target)
      place_addition(target, payment_type: FactoryBot.create(:credit_card_payment_type),
                             lines: [[seat_class, 1]], **card_details)
      target.reload
    end

    it 'refunds each card payment against its own charge' do
      target = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card, performance: performance)
      gateway
      add_card_paid_seat(target)
      charges = target.payments.grep(CreditCardPayment).to_h { |p| [p.transaction_id, (p.amount * 100).to_i] }
      expect(charges.keys).to contain_exactly('TEST_TRANSACTION', 'ch_addition')

      target.refund!

      charges.each do |charge_id, cents|
        expect(gateway).to have_received(:refund).with(cents, charge_id, anything).once
      end
      expect(target.reload.status).to eq(Order::REFUNDED)
      expect(target.total_paid).to eq(0)
    end

    it "refunds the card and releases the membership's tickets so its cap frees up" do
      target = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_membership, performance: performance)
      membership = target.membership_payments.first.membership
      gateway
      add_card_paid_seat(target)

      target.refund!

      target.reload
      expect(gateway).to have_received(:refund).with(seat_class.ticket_price * 100, 'ch_addition', anything).once
      expect(target.payments.grep(MembershipPayment).sum(&:number_of_tickets)).to eq(0)
      expect(target.status).to eq(Order::REFUNDED)

      again = TicketOrder.new(status: Order::NEW, performance: performance, address: membership.address,
                              payment_type: FactoryBot.create(:membership_payment_type))
      again.ticket_line_items << TicketLineItem.new(ticket_class: seat_class, ticket_count: 2)
      again.save!
      again.payments << FactoryBot.create(:membership_payment, order: again, membership: membership,
                                                               number_of_tickets: 2, amount: 0)
      expect { membership.verify_applicable_for(again) }.not_to raise_error
    end
  end
end
