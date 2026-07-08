require 'rails_helper'
require 'stripe_mock'

RSpec.shared_examples "a paid ticket order" do |pay_method_type, seating_type|
  let(:pay_method) { pay_method_type }
  let(:seating) { seating_type }
  let(:stripe_helper) { StripeMock.create_test_helper }
  before { StripeMock.start }
  after { StripeMock.stop }

  it "can be refunded" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method, seating)
    unless o.paid_with_pass?
      expect(o.total_paid).to be > 0.0
      o.refund!
      expect(o.total_paid).to eq(0)
    end
  end

  it "should mark its holder has having attended the production when fulfilled" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method, seating)
    # There is something weird about the setup for membership ticket facotries that screws up this test.
    expect(o.production.addresses.size).to eq(0)

    expect(o.address.productions.size).to eq(0)
    total_records = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM addresses_productions").first[0]
    o.transition_to!(Order::FULFILLED)
    o.production.reload
    o.address.reload
    expect(o.address.productions.size).to eq(1)
    expect(o.production.addresses.size).to eq(1)
  end
  it "should unmark the holder has having attended when refunded" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method, seating)
    o.transition_to!(Order::FULFILLED)
    production = o.performance.production
    o.refund!
    expect(o.performance.production.addresses.size).to eq(0)
  end
  it "should unmark the holder has having attended when unclaimed" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method, seating)
    o.transition_to!(Order::FULFILLED)
    o.transition_to!(Order::UNCLAIMED)
    expect(o.performance.production.addresses.count).to eq(0)
  end
  context "when splitting" do
    it "creates two orders that reference the original order" do
      original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method, seating)
      original_total = original_order.total_paid
      expect(original_total).to eq(12)
      old_tli = original_order.flatten_ticket_line_items
      new_tli = [old_tli[0]]
      original_status = original_order.status
      original_seats = original_order.number_of_seats
      original_amount = original_order.total_paid
      result = original_order.split(new_tli)
      expect(result.size).to eq(2)
      split_order1, split_order2 = result
      expect(original_order.status).to eq(TicketOrder::SPLIT)
      expect(split_order1.status).to eq(original_status)
      expect(split_order2.status).to eq(original_status)
      expect(original_order.number_of_seats).to eq(0)
      expect(split_order1.number_of_seats).to eq(1)
      expect(split_order2.number_of_seats).to eq(original_seats - 1)
      expect(split_order1.payments.size).to be >= 1
      expect(split_order2.payments.size).to be >= 1
      expect(original_order.ticket_line_items.size).to eq(3)

      expect(original_order.total_paid).to eq(0)
      expect(original_order.customer_visible_total).to eq(0.0)
      expect(split_order1.total_paid).to eq(original_total / 2.0)
      expect(split_order2.total_paid).to eq(original_total / 2.0)
      expect(split_order1.split_source_id).to eq(original_order.id)
      expect(split_order2.split_source_id).to eq(original_order.id)
      expect(split_order1.split_source.id).to eq(original_order.id)
      expect(split_order2.split_source.id).to eq(original_order.id)
    end
  end
end

RSpec.describe TicketOrder do
  include_context 'auto-fulfilling print service'

  it_behaves_like "a paid ticket order", :paid_with_cash, :general_admission
  it_behaves_like "a paid ticket order", :paid_with_credit_card, :general_admission
  it_behaves_like "a paid ticket order", :paid_with_membership, :general_admission
  it_behaves_like "a paid ticket order", :paid_with_flex_pass, :general_admission
  it_behaves_like "a paid ticket order", :paid_with_external, :general_admission
  it_behaves_like "a paid ticket order", :paid_with_cash, :reserved_seating
  it_behaves_like "a paid ticket order", :paid_with_credit_card, :reserved_seating
  it_behaves_like "a paid ticket order", :paid_with_membership, :reserved_seating
  it_behaves_like "a paid ticket order", :paid_with_flex_pass, :reserved_seating
  it_behaves_like "a paid ticket order", :paid_with_external, :reserved_seating

  it "ensures that membership quotas/production are honored" do
    address = FactoryBot.create(:address)
    membership_offer = FactoryBot.create(:membership_offer, tickets_per_performance: 1)
    membership = FactoryBot.create(:membership, address: address, membership_offer: membership_offer)
    expect(membership.membership_offer.tickets_per_performance).to eq(1)
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, address: address, member_code: membership.member_code)
    o.payment_type = FactoryBot.create(:membership_payment_type)
    expect { o.transition_to!(Order::FULFILLED) }.to raise_error(Exceptions::TooManyTicketsForMembership)
  end

  describe "festival-restricted flex pass gate" do
    let(:festival) { FactoryBot.create(:festival) }

    def flex_pass_for(offer)
      FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass
    end

    def flex_pass_order_on(production, pass)
      performance = FactoryBot.create(:general_admission, production: production)
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_flex_pass,
                                performance: performance, flex_pass_code: pass.code)
      order.reload
      order
    end

    it "accepts a flex pass redeemed on a production in the offer's festival" do
      offer = FactoryBot.create(:flex_pass_offer, festival: festival)
      pass = flex_pass_for(offer)
      order = flex_pass_order_on(FactoryBot.create(:production, festival: festival), pass)

      expect { order.flex_pass_payments.first.process!(order) }.not_to raise_error
    end

    it "rejects a flex pass redeemed on a production in a different festival" do
      offer = FactoryBot.create(:flex_pass_offer, festival: festival)
      pass = flex_pass_for(offer)
      other_festival = FactoryBot.create(:festival)
      order = flex_pass_order_on(FactoryBot.create(:production, festival: other_festival), pass)

      expect { order.flex_pass_payments.first.process!(order) }
        .to raise_error(/only valid for #{festival.name} shows/)
    end

    it "rejects a festival flex pass redeemed on a production with no festival" do
      offer = FactoryBot.create(:flex_pass_offer, festival: festival)
      pass = flex_pass_for(offer)
      order = flex_pass_order_on(FactoryBot.create(:production), pass)

      expect { order.flex_pass_payments.first.process!(order) }
        .to raise_error(/only valid for #{festival.name} shows/)
    end

    it "leaves unrestricted flex passes usable on any production (no festival gate)" do
      offer = FactoryBot.create(:flex_pass_offer, festival: nil)
      pass = flex_pass_for(offer)
      order = flex_pass_order_on(FactoryBot.create(:production, festival: festival), pass)

      expect { order.flex_pass_payments.first.process!(order) }.not_to raise_error
    end

    it "still enforces the theater gate alongside the festival gate (additive)" do
      offer_theater = FactoryBot.create(:theater)
      offer = FactoryBot.create(:flex_pass_offer, festival: festival,
                                                  theater: offer_theater, exclude_theater: false)
      pass = flex_pass_for(offer)
      # Production is in the festival but at a different theater: the untouched
      # theater gate fires first, proving the festival gate is purely additive.
      production = FactoryBot.create(:production, festival: festival, theater: FactoryBot.create(:theater))
      order = flex_pass_order_on(production, pass)

      expect { order.flex_pass_payments.first.process!(order) }
        .to raise_error(/restricted to #{offer_theater.name}/)
    end
  end

  describe "membership festival advance cap" do
    let(:festival) { FactoryBot.create(:festival) }
    let(:prod_a) { FactoryBot.create(:production, festival: festival) }
    let(:prod_b) { FactoryBot.create(:production, festival: festival) }
    let(:perf_a) { FactoryBot.create(:general_admission, production: prod_a) }
    let(:perf_b) { FactoryBot.create(:general_admission, production: prod_b) }

    def membership_with_cap(cap)
      # High per-performance limit keeps the unrelated per-performance/per-production
      # checks from firing so these examples isolate the festival advance cap.
      offer = FactoryBot.create(:membership_offer, tickets_per_performance: 10,
                                                   max_festival_tickets_in_advance: cap)
      FactoryBot.create(:membership, membership_offer: offer)
    end

    # Persist a prior processed order that consumes festival tickets, bypassing
    # validation so setup can build up state independent of the cap under test.
    def consume_festival_tickets(membership, performance, tickets)
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket,
                                address: membership.address, performance: performance)
      order.payments << FactoryBot.build(:membership_payment, number_of_tickets: tickets,
                                                              membership: membership, amount: 0)
      order.status = Order::PROCESSED
      order.save!(validate: false)
      order
    end

    # A persisted-but-unprocessed order requesting festival tickets to run verify
    # against (real orders always have an id by the time this cap is checked).
    def pending_festival_order(membership, performance, tickets, box_office: false)
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket,
                                address: membership.address, performance: performance)
      order.box_office_sale = box_office
      order.payments << FactoryBot.build(:membership_payment, number_of_tickets: tickets,
                                                              membership: membership, amount: 0)
      order
    end

    it "allows a request that stays under the festival cap" do
      membership = membership_with_cap(2)
      order = pending_festival_order(membership, perf_b, 1)

      expect { membership.verify_applicable_for(order) }.not_to raise_error
    end

    it "allows a request that exactly reaches the festival cap across two productions" do
      membership = membership_with_cap(2)
      consume_festival_tickets(membership, perf_a, 1)
      order = pending_festival_order(membership, perf_b, 1)

      expect { membership.verify_applicable_for(order) }.not_to raise_error
    end

    it "blocks a web request that exceeds the festival cap across two productions" do
      membership = membership_with_cap(2)
      consume_festival_tickets(membership, perf_a, 2)
      order = pending_festival_order(membership, perf_b, 1)

      expect { membership.verify_applicable_for(order) }
        .to raise_error(Exceptions::FestivalTicketsAtDoorOnly,
                        /covers 2 #{festival.name} tickets in advance/)
    end

    it "uses singular 'ticket' when the cap is one" do
      membership = membership_with_cap(1)
      consume_festival_tickets(membership, perf_a, 1)
      order = pending_festival_order(membership, perf_b, 1)

      expect { membership.verify_applicable_for(order) }
        .to raise_error(Exceptions::FestivalTicketsAtDoorOnly,
                        /covers 1 #{festival.name} ticket in advance/)
    end

    it "lets box office sales exceed the festival cap" do
      membership = membership_with_cap(2)
      consume_festival_tickets(membership, perf_a, 2)
      order = pending_festival_order(membership, perf_b, 5, box_office: true)

      expect { membership.verify_applicable_for(order) }.not_to raise_error
    end

    it "is a no-op when the offer has no festival cap" do
      membership = membership_with_cap(nil)
      consume_festival_tickets(membership, perf_a, 5)
      order = pending_festival_order(membership, perf_b, 5)

      expect { membership.verify_applicable_for(order) }.not_to raise_error
    end

    it "is a no-op for productions that are not in a festival" do
      membership = membership_with_cap(1)
      plain_perf = FactoryBot.create(:general_admission, production: FactoryBot.create(:production))
      order = pending_festival_order(membership, plain_perf, 10)

      expect { membership.verify_applicable_for(order) }.not_to raise_error
    end

    it "leaves the same-show RepeatVisitsAtDoorOnly rule untouched" do
      membership = membership_with_cap(nil)
      plain_prod = FactoryBot.create(:production)
      plain_perf = FactoryBot.create(:general_admission, production: plain_prod)
      pass_class = plain_prod.ticket_classes.find do |tc|
        tc.class_code == membership.membership_offer.use_ticket_class_code
      end

      prior = FactoryBot.build(:ticket_order, address: membership.address, performance: plain_perf)
      prior.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: pass_class,
                                                                     ticket_count: 1, order: prior)
      prior.save!
      prior.payments << FactoryBot.build(:membership_payment, number_of_tickets: 1,
                                                              membership: membership, amount: 0)
      prior.status = Order::PROCESSED
      prior.save!(validate: false)

      order = pending_festival_order(membership, plain_perf, 1)
      expect { membership.verify_applicable_for(order) }
        .to raise_error(Exceptions::RepeatVisitsAtDoorOnly)
    end
  end

  it "should preserve the attendance when cancelling one of multiple reservations" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    a = o.address
    o.transition_to!(Order::FULFILLED)
    expect(o.performance.production.addresses.count).to eq(1)
    o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance => o.performance)
    o2.address = a
    o2.save!
    o2.transition_to!(Order::FULFILLED)

    expect(o2.performance.production.addresses.uniq.size).to eq(1)

    o2.transition_to!(Order::UNCLAIMED)
    expect(o2.performance.production.addresses.uniq.size).to eq (1)
  end

  it "does not block off seats when unclaimed" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    o2 = o.dup
    o2.status = Order::NEW
    o2.uuid = SecureRandom.uuid
    o2.save!
    o2.ticket_line_items << o.ticket_line_items.first.dup
    o2.payment_type = FactoryBot.create(:cash_payment_type)
    o2.transition_to!(Order::PROCESSED)
    o2.performance.production.capacity = 10
    o2.performance.production.save!

    o2.performance.reload
    expect(o2.performance.number_of_seats_left).to eq(6)
    o2.transition_to!(Order::FULFILLED)
    expect(o2.performance.number_of_seats_left).to eq(6)
    o2.transition_to!(Order::UNCLAIMED)
    o2.performance.reload
    expect(o2.performance.number_of_seats_left).to eq(8)
  end

  it "can prevent receipt emails from being generated for ticket classes that disallow receipts" do
    start_count = OutreachTask.where(method_symbol: :ticket_confirmation).count
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    expect(OutreachTask.where(method_symbol: :ticket_confirmation).count).to eq(start_count + 1)
    o.ticket_line_items.first.ticket_class.suppress_receipt = true
    o.ticket_line_items.first.ticket_class.save!
    o2 = o.dup
    o2.status = Order::NEW
    o2.ticket_line_items << o.ticket_line_items.first.dup
    o2.payment_type = FactoryBot.create(:cash_payment_type)
    o2.uuid = SecureRandom.uuid
    o2.save!
    o2.transition_to!(Order::PROCESSED)
    expect(OutreachTask.where(method_symbol: :ticket_confirmation).count).to eq(start_count + 1)
  end

  it "can create up to two additional donation orders" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)
    expect(DonationOrder.count).to eq(0)
    o.additional_donation = 50.00
    o.additional_donation_for_other = 1.66
    expect(o.total_due).to eq(12.00)
    o.transition_to!(Order::PROCESSED)
    donation_orders = DonationOrder.all.to_a.sort_by { |d| -d.total_paid }
    expect(donation_orders.count).to eq(2)
    expect(donation_orders[0].total_paid).to eq(50.00)
    expect(donation_orders[1].total_paid).to eq(1.66)
    expect(donation_orders[0].campaign).not_to be_blank
    expect(donation_orders[1].campaign).not_to be_blank
    expect(donation_orders[1].theater).to eq(Theater.first)
    expect(donation_orders[0].theater).to eq(Theater.first)
  end

  context "when overselling" do
    it "cannot processes if it would oversell a particular ticket class" do
      production = FactoryBot.create(:production, :capacity => 4)
      performance = FactoryBot.create(:performance, :production => production)
      expect(performance.number_of_seats_left).to eq(4)
      o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance => performance)
      o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance => performance)
      expect(performance.number_of_seats_left).to eq(0)

      expect do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :performance => performance)
        order.transition_to!(Order::PROCESSING)
        order.errors.each do |error|
          puts "#{error.message}, #{error.attribute.to_yaml}"
        end
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "cannot processes if it would oversell a performance" do
      production = FactoryBot.create(:production, :capacity => 2)
      tc_1 = FactoryBot.create(:ticket_class, :production => production, :class_code => 'CODEA')
      tc_2 = FactoryBot.create(:ticket_class, :production => production, :class_code => 'CODEB')
      tc_3 = FactoryBot.create(:ticket_class, :production => production, :class_code => 'CODEC')
      production.reload
      performance = FactoryBot.create(:performance, :production => production)

      expect(performance.number_of_seats_left).to eq(2)
      expect(tc_1.number_left(performance)).to eq(2)
      expect(tc_2.number_left(performance)).to eq(2)
      expect(tc_3.number_left(performance)).to eq(2)

      o = FactoryBot.create(:ticket_order, :performance => performance)
      o.ticket_line_items << FactoryBot.build(
        :ticket_line_item,
        :ticket_class => tc_1,
        :ticket_count => 1,
        :order => o
      )
      expect(tc_1.number_left(performance)).to eq(1)
      expect(tc_2.number_left(performance)).to eq(1)
      expect(tc_2.number_left(performance)).to eq(1)

      o.ticket_line_items << FactoryBot.build(
        :ticket_line_item,
        :ticket_class => tc_2,
        :ticket_count => 2,
        :order => o
      )
      expect(tc_1.number_left(performance)).to eq(-1)
      expect(tc_2.number_left(performance)).to eq(-1)
      expect(tc_2.number_left(performance)).to eq(-1)

      # o.ticket_line_items << FactoryBot.create(
      #                            :ticket_line_item,
      #                            :ticket_class=>tc_3,
      #                            :ticket_count=>1,
      #                            :order=>o)
      expect(o.number_of_seats).to eq(3)

      expect { o.transition_to!(Order::PROCESSING) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "can mark an order in a sold-out performance as unclaimed" do
      production = FactoryBot.create(:production, :capacity => 4)
      performance = FactoryBot.create(:performance, :production => production)
      o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance => performance)
      o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance => performance)
      o.transition_to!(Order::FULFILLED)
      o2.transition_to!(Order::FULFILLED)
      expect(performance.number_of_seats_left).to eq(0)
      o.transition_to!(Order::UNCLAIMED)
      expect(performance.number_of_seats_left).to eq(2)
    end

    it "creates tasks for asynchronous post-operation, except where prohibited by the payment type" do
      o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      task_count = o.tasks.count
      expect(task_count).to be > 0
      payment_type = o.payment_type
      payment_type.order_task_suppressions << FactoryBot.create(:order_task_suppression, task_type: o.tasks.first.type,
                                                                                         method_name: o.tasks.first.method_symbol)
      payment_type.save
      o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      expect(o2.tasks.count).to eq(task_count)
      t = o2.tasks.first
      t.run!
      expect(t.status).to eq('Cancelled')
    end

    it "can be held under a different name but not under an email" do
      o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      o.hold_under = "Another Name"
      expect(o.save).to equal(true)
      expect(o.hold_under).to eq('Another Name')
      o.hold_under = 'bad@email.com'
      expect(o.save).to equal(false)
    end
  end

  context "to an event that is not a performance" do
    before(:each) do
      @ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      @ticket_order.performance.production.production_class = Production::CLASS
      @ticket_order.performance.production.save
    end

    it "sends a simplified confirmation email" do
      mail = OrderMailer.ticket_confirmation(@ticket_order)
      expect(mail.body.encoded).not_to match("Dining")
      expect(mail.body.encoded).not_to match("seating")
      expect(mail.body.encoded).to match("reservation")
    end

    it "does not send an automatic followup" do
      followups = @ticket_order.tasks.select { |t| t.method_symbol&.include?('followup') }
      expect(followups.count).to eq(0)
    end
  end

  context "when exchanging" do
    it "allows an exchange with an external payment to a performance that is cheaper" do
      ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_external)
      original_price = ticket_order.total_paid
      performance2 = ticket_order.performance.dup
      ticket_class = FactoryBot.create(:ticket_class, :ticket_price => 1.0, class_code: 'EXCH',
                                                      production: ticket_order.performance.production)
      performance2.performance_date = ticket_order.performance.performance_date + 1.day
      performance2.performance_code += "A"
      performance2.save!
      performance2.reload
      exchange_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance2)
      exchange_order.ticket_line_items[0].ticket_class = ticket_class
      exchange_order.exchange_and_process_from!(ticket_order)
      amt = exchange_order.payments.inject(0.0) { |sum, p| sum += p.is_a?(PriceOverridePayment) ? p.amount : 0.0 }
      expect(amt).to eq(2.0 - original_price)
      expect(exchange_order.total_paid).to eq(2.0)
      expect(exchange_order.total_override_payments).to eq(-10.0)
    end
  end

  context "when splitting" do
    it "replicates existing tasks and state" do
      original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      expect(original_order.tasks.size).to eql(2)
      notify_task = original_order.tasks.first
      notify_task.status = OrderTask::COMPLETED
      notify_task.save
      old_tli = original_order.flatten_ticket_line_items
      new_tli = [old_tli[0]]
      order1, order2 = original_order.split(new_tli)
      expect(order1.tasks.size).to eql(2)
      expect(order1.tasks.first.status).to eql("Completed")
      expect(order2.tasks.size).to eql(2)
      expect(order2.tasks.first.status).to eql("Completed")
    end

    it "cancels pending tasks after split" do
      original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      expect(original_order.tasks.size).to eql(2)
      old_tli = original_order.flatten_ticket_line_items
      new_tli = [old_tli[0]]
      order1, order2 = original_order.split(new_tli)
      expect(order1.tasks.size).to eql(2)
      expect(order1.tasks.first.status).to eql(OrderTask::UNTRIED)
      expect(order2.tasks.size).to eql(2)
      expect(order2.tasks.first.status).to eql(OrderTask::UNTRIED)
      expect(original_order.tasks.first.status == OrderTask::CANCELLED)
    end

    # Regression for the per-seat TLI shape introduced by commit bf0e8cb3:
    # each seat is its own TLI (ticket_count: 1) carrying a unique
    # seat_assignment_id FK. The split path used to leave the source TLI's FK
    # populated, so the split-order dup hit the unique index on
    # line_items.seat_assignment_id.
    it "splits reserved-seat orders whose TLIs are per-seat (unique seat_assignment_id)" do
      original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :reserved_seating)
      aggregated_tli = original_order.ticket_line_items.first
      seats = original_order.seats.to_a
      expect(seats.size).to eq(2)

      # Reshape into one TLI per seat with seat_assignment_id populated, the
      # shape produced by the post-bf0e8cb3 reserved-seat checkout flow.
      original_order.ticket_line_items.destroy_all
      seats.each do |seat|
        original_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
                                                              ticket_class: aggregated_tli.ticket_class,
                                                              ticket_count: 1,
                                                              order: original_order,
                                                              seat_assignment_id: seat.id)
      end
      original_order.save!
      original_order.reload

      flat = original_order.flatten_ticket_line_items
      expect(flat.size).to eq(2)
      expect(flat.map { |t| t[:seat]&.id }.compact.sort).to eq(seats.map(&:id).sort)

      expect do
        @result = original_order.split([flat[0]], flat)
      end.not_to raise_error

      order1, order2 = @result
      expect(order1).not_to be_nil
      expect(order2).not_to be_nil

      original_order.reload
      surviving_originals = original_order.ticket_line_items.where("ticket_count > 0")
      expect(surviving_originals.pluck(:seat_assignment_id).compact).to eq([])

      [order1, order2].each do |split_order|
        split_order.reload
        positive_tlis = split_order.ticket_line_items.where("ticket_count > 0")
        expect(positive_tlis.size).to eq(1)
        expect(positive_tlis.first.seat_assignment_id).to be_present
      end

      assigned_ids = [order1, order2].flat_map { |o| o.ticket_line_items.pluck(:seat_assignment_id) }.compact
      expect(assigned_ids.sort).to eq(seats.map(&:id).sort)
    end

    # The split form pairs TLIs and seats by row index. If the user reorders
    # rows, the source TLI passed in tli_hash[:source] may carry a
    # seat_assignment_id FK pointing at a *different* seat than the one in
    # tli_hash[:seat]. Both source FKs must still be released so neither dup
    # collides with a leftover original on the unique index.
    it "splits per-seat orders even when the form pairs each TLI with the other TLI's seat" do
      original_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :reserved_seating)
      aggregated_tli = original_order.ticket_line_items.first
      seats = original_order.seats.to_a
      expect(seats.size).to eq(2)

      original_order.ticket_line_items.destroy_all
      seats.each do |seat|
        original_order.ticket_line_items << FactoryBot.create(:ticket_line_item,
                                                              ticket_class: aggregated_tli.ticket_class,
                                                              ticket_count: 1,
                                                              order: original_order,
                                                              seat_assignment_id: seat.id)
      end
      original_order.save!
      original_order.reload
      tlis = original_order.ticket_line_items.order(:id).to_a

      # Build the flattened list with the seats *swapped* relative to each
      # TLI's seat_assignment_id, mimicking the index-based form pairing.
      swapped = [
        { source: tlis[0], seat: seats[1], ticket_class_id: tlis[0].ticket_class_id },
        { source: tlis[1], seat: seats[0], ticket_class_id: tlis[1].ticket_class_id },
      ]

      expect do
        @result = original_order.split([swapped[0]], swapped)
      end.not_to raise_error

      order1, order2 = @result
      expect(order1).not_to be_nil
      expect(order2).not_to be_nil
      assigned_ids = [order1, order2].flat_map { |o| o.ticket_line_items.pluck(:seat_assignment_id) }.compact
      expect(assigned_ids.sort).to eq(seats.map(&:id).sort)
    end
  end

  it "creates two orders that round down when they are not divisible" do
    original_order = FactoryBot.create(:ticket_order, :with_wierd_special_offer, :for_three_tickets,
                                       :with_twenty_dollar_service_item, :paid_with_cash)
    original_total = original_order.total_paid
    expect(original_total).to eq(32.03)
    old_tli = original_order.flatten_ticket_line_items
    new_tli = [old_tli[0]]
    original_status = original_order.status
    original_seats = original_order.number_of_seats
    original_amount = original_order.total_paid
    result = original_order.split(new_tli)
    expect(result.size).to eq(2)
    split_order1, split_order2 = result
    expect(split_order1.payments.size).to be > (0)
    expect(split_order2.payments.size).to be > (0)
    expect(original_order.status).to eq(TicketOrder::SPLIT)
    expect(split_order1.status).to eq(original_status)
    expect(split_order2.status).to eq(original_status)
    expect(original_order.number_of_seats).to eq(0)
    expect(split_order1.number_of_seats).to eq(1)
    expect(split_order2.number_of_seats).to eq(original_seats - 1)
    expect(original_order.ticket_line_items.size).to eq(5)
    expect(original_order.total_paid).to eq(20.0)
    expect(split_order1.total_paid).to eq(4.01)
    expect(split_order1.ticket_line_items.size).to eq(1)
    expect(split_order2.ticket_line_items.size).to eq(2)
    expect(split_order2.total_paid).to eq(8.02)
    expect(split_order1.total_paid + split_order2.total_paid + original_order.total_paid).to eq(original_amount)
    expect(split_order1.split_source_id).to eq(original_order.id)
    expect(split_order2.split_source_id).to eq(original_order.id)
    expect(split_order1.split_source.id).to eq(original_order.id)
    expect(split_order2.split_source.id).to eq(original_order.id)
  end

  it "creates two orders that manage an order with an uneven number of tickets and a service charge" do
    original_order = FactoryBot.create(:ticket_order, :with_twenty_dollar_service_item, :for_three_tickets,
                                       :paid_with_cash)
    original_total = original_order.total_paid
    old_tli = original_order.flatten_ticket_line_items
    new_tli = [old_tli[0]]
    original_status = original_order.status
    original_seats = original_order.number_of_seats
    original_amount = original_order.total_paid
    result = original_order.split(new_tli)
    expect(result.size).to eq(2)
    split_order1, split_order2 = result
    expect(original_order.status).to eq(TicketOrder::SPLIT)
    expect(split_order1.status).to eq(original_status)
    expect(split_order2.status).to eq(original_status)
    expect(original_order.number_of_seats).to eq(0)
    expect(split_order1.number_of_seats).to eq(1)
    expect(split_order2.number_of_seats).to eq(original_seats - 1)
    expect(original_order.ticket_line_items.size).to eq(5)
    expect(original_order.total_paid).to eq(20.01)
    expect(split_order1.total_paid).to eq(4.83)
    expect(split_order1.ticket_line_items.size).to eq(1)
    expect(split_order2.ticket_line_items.size).to eq(2)
    expect(split_order2.total_paid).to eq(9.66)
    expect(split_order1.split_source_id).to eq(original_order.id)
    expect(split_order2.split_source_id).to eq(original_order.id)
    expect(split_order1.split_source.id).to eq(original_order.id)
    expect(split_order2.split_source.id).to eq(original_order.id)
  end

  context "seat assignment validation" do
    context "for reserved seating orders" do
      it "allows NEW orders to be saved without complete seat assignments" do
        # Create order with NEW status
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        # Clear seats to simulate user hasn't selected them yet
        SeatAssignment.where(order_uuid: order.uuid).update_all(
          order_uuid: nil,
          status: SeatAssignment::AVAILABLE,
          ticket_class_id: nil
        )
        order.reload

        expect(order.status).to eq(Order::NEW)
        expect(order.seating_check_required?).to eq(false)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(0)
        # Should be valid despite seat mismatch because it's NEW
        expect(order.valid?).to eq(true)
      end

      it "fails validation for HOLD orders with mismatched seat/ticket counts" do
        # Create order with NEW status (factory auto-assigns 2 seats)
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        # Set to HOLD status and add an extra seat to create mismatch (now has 3 seats for 2 tickets)
        order.update_column(:status, Order::HOLD)
        extra_seat = order.performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).first
        extra_seat.update!(
          order_uuid: order.uuid,
          status: SeatAssignment::ASSIGNED,
          ticket_class_id: order.ticket_line_items.first.ticket_class_id
        )
        order.reload

        expect(order.status).to eq(Order::HOLD)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(3)
        expect(order.seating_check_required?).to eq(true)
        expect(order.valid?).to eq(false)
        expect(order.errors.full_messages).to include(match(/seats.*do not match tickets/i))
      end

      it "fails validation for PROCESSING orders with mismatched seat/ticket counts" do
        # Create with NEW status (factory auto-assigns 2 seats)
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        # Set to PROCESSING and add extra seat
        order.update_column(:status, Order::PROCESSING)
        extra_seat = order.performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).first
        extra_seat.update!(
          order_uuid: order.uuid,
          status: SeatAssignment::ASSIGNED,
          ticket_class_id: order.ticket_line_items.first.ticket_class_id
        )
        order.reload

        expect(order.status).to eq(Order::PROCESSING)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(3)
        expect(order.seating_check_required?).to eq(true)
        expect(order.valid?).to eq(false)
        expect(order.errors.full_messages).to include(match(/seats.*do not match tickets/i))
      end

      it "fails validation for PROCESSED orders with mismatched seat/ticket counts" do
        # Create with NEW status (factory auto-assigns 2 seats)
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        # Set to PROCESSED and add extra seat
        order.update_column(:status, Order::PROCESSED)
        extra_seat = order.performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).first
        extra_seat.update!(
          order_uuid: order.uuid,
          status: SeatAssignment::ASSIGNED,
          ticket_class_id: order.ticket_line_items.first.ticket_class_id
        )
        order.reload

        expect(order.status).to eq(Order::PROCESSED)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(3)
        expect(order.seating_check_required?).to eq(true)
        expect(order.valid?).to eq(false)
        expect(order.errors.full_messages).to include(match(/seats.*do not match tickets/i))
      end

      it "fails validation for FULFILLED orders with mismatched seat/ticket counts" do
        # Create with NEW status (factory auto-assigns 2 seats)
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        # Set to FULFILLED and add extra seat
        order.update_column(:status, Order::FULFILLED)
        extra_seat = order.performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).first
        extra_seat.update!(
          order_uuid: order.uuid,
          status: SeatAssignment::ASSIGNED,
          ticket_class_id: order.ticket_line_items.first.ticket_class_id
        )
        order.reload

        expect(order.status).to eq(Order::FULFILLED)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(3)
        expect(order.seating_check_required?).to eq(true)
        expect(order.valid?).to eq(false)
        expect(order.errors.full_messages).to include(match(/seats.*do not match tickets/i))
      end

      it "passes validation for HOLD orders with matching seat/ticket counts" do
        # Create with NEW status (factory auto-assigns 2 seats matching 2 tickets)
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        order.update_column(:status, Order::HOLD)
        order.reload

        expect(order.status).to eq(Order::HOLD)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(2)
        expect(order.seating_check_required?).to eq(true)
        expect(order.valid?).to eq(true)
      end

      it "passes validation for PROCESSED orders with matching seat/ticket counts" do
        # Create with NEW status (factory auto-assigns 2 seats matching 2 tickets)
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)

        order.update_column(:status, Order::PROCESSED)
        order.reload

        expect(order.status).to eq(Order::PROCESSED)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(2)
        expect(order.seating_check_required?).to eq(true)
        expect(order.valid?).to eq(true)
      end
    end

    context "for general admission orders" do
      it "does not require seat validation regardless of status" do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :general_admission, :paid_with_cash)

        expect(order.performance.production.has_reserved_seating?).to eq(false)
        expect(order.number_of_tickets).to eq(2)
        expect(order.seats.count).to eq(0)
        expect(order.valid?).to eq(true)
      end
    end

    context "for terminal order statuses" do
      it "does not require seat validation for REFUNDED orders with 0 tickets" do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)
        order.update_column(:status, Order::REFUNDED)

        # Simulate refund by setting ticket counts to 0
        order.ticket_line_items.each { |tli| tli.update_column(:ticket_count, 0) }
        order.reload

        expect(order.status).to eq(Order::REFUNDED)
        expect(order.number_of_tickets).to eq(0)
        expect(order.seating_check_required?).to eq(false)
        expect(order.valid?).to eq(true)
      end

      it "does not require seat validation for EXCHANGED orders" do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)
        order.update_column(:status, Order::EXCHANGED)
        order.reload

        expect(order.status).to eq(Order::EXCHANGED)
        expect(order.seating_check_required?).to eq(false)
      end

      it "does not require seat validation for UNCLAIMED orders" do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)
        order.update_column(:status, Order::UNCLAIMED)
        order.reload

        expect(order.status).to eq(Order::UNCLAIMED)
        expect(order.seating_check_required?).to eq(false)
      end

      it "does not require seat validation for SPLIT orders" do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)
        order.update_column(:status, Order::SPLIT)
        order.reload

        expect(order.status).to eq(Order::SPLIT)
        expect(order.seating_check_required?).to eq(false)
      end

      it "does not require seat validation for CANCELED orders" do
        order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, status: Order::NEW)
        order.update_column(:status, Order::CANCELED)
        order.reload

        expect(order.status).to eq(Order::CANCELED)
        expect(order.seating_check_required?).to eq(false)
      end
    end
  end

  context "royalty_gross" do
    it "uses ticket_price when royalty_amount is not set" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      expect(tc.royalty_amount).to be_nil
      # With no royalty_amount and ticketing_fee of 0, royalty_gross = ticket_price * count
      expected = tc.ticket_price * order.number_of_tickets
      expect(order.royalty_gross).to eq(expected)
    end

    it "deducts facility fee when royalty_amount is not set" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_column(:ticketing_fee, 1.50)
      # royalty_gross should deduct facility fee since ticket_price includes it
      expected = (tc.ticket_price * order.number_of_tickets) - (1.50 * order.number_of_tickets)
      expect(order.royalty_gross).to eq(expected)
    end

    it "uses royalty_amount when set on the ticket class" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_column(:royalty_amount, 4.00)
      tc.reload
      # royalty_amount is exclusive of facility fee, so no deduction
      expected = 4.00 * order.number_of_tickets
      expect(order.royalty_gross).to eq(expected)
    end

    it "does not deduct facility fee when royalty_amount is set" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_columns(royalty_amount: 4.00, ticketing_fee: 1.50)
      tc.reload
      # royalty_amount already excludes facility fee
      expected = 4.00 * order.number_of_tickets
      expect(order.royalty_gross).to eq(expected)
    end

    it "applies percent-off discount recalculated against royalty prices" do
      order = FactoryBot.create(:ticket_order, :with_wierd_special_offer, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_column(:royalty_amount, 5.00)
      tc.reload
      # 17% off special offer, 2 tickets at $5 royalty
      royalty_ticket_total = 5.00 * order.number_of_tickets
      discount = (royalty_ticket_total * 17 / -100.0).round(2)
      expected = royalty_ticket_total + discount
      expect(order.royalty_gross).to eq(expected)
    end

    it "applies amount-off discount against royalty total" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_column(:royalty_amount, 5.00)
      tc.reload
      amount_off = FactoryBot.create(:amount_off_special_offer, amount: 1.00)
      order.build_special_offer_line_item(special_offer: amount_off)
      order.save!
      # $1 off per ticket, 2 tickets at $5 royalty
      expected = (5.00 * 2) - (1.00 * 2)
      expect(order.royalty_gross).to eq(expected)
    end

    it "calculates proportional royalty for split orders" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_column(:royalty_amount, 4.00)
      tc.reload
      original_total = order.total_paid
      old_tli = order.flatten_ticket_line_items
      new_tli = [old_tli[0]]
      split_order1, split_order2 = order.split(new_tli)

      # Each split ticket gets price_override = (total_paid - service_fees) / num_tickets
      # ratio = price_override / ticket_price
      # royalty = royalty_amount * ratio * count
      split_tli = split_order1.ticket_line_items.first
      expect(split_tli.generated_from_split?).to be true
      ratio = split_tli.price_override / tc.ticket_price
      expected = (4.00 * ratio * split_tli.ticket_count).round(2)
      expect(split_order1.royalty_gross).to eq(expected)
    end

    it "returns zero for exchanged orders with zero total_paid" do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      tc = order.ticket_line_items.first.ticket_class
      tc.update_column(:royalty_amount, 5.00)
      # Simulate an exchanged order with offset payments zeroing out total_paid
      order.payments.each { |p| p.update_column(:amount, 0) }
      order.reload
      expect(order.total_paid).to eq(0)
      expect(order.royalty_gross).to eq(0)
    end
  end
end
