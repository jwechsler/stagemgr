require 'rails_helper'

RSpec.shared_examples "a paid ticket order" do |payment_type|
  let(:pay_method) {payment_type}
  it "can be refunded" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method)
    expect(o.total).to be > 0.0
    o.refund!
    expect(o.total).to eq(0)
  end
  it "should mark its holder has having attended the production when fulfilled" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method)
    o.transition_to!(Order::FULFILLED)
    expect(o.performance.production.attendees.size).to eq(1)
  end
  it "should unmark the holder has having attended when refunded" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method)
    o.transition_to!(Order::FULFILLED)
    production = o.performance.production
    o.refund!
    expect(o.performance.production.attendees.size).to eq(0)
  end
   it "should unmark the holder has having attended when unclaimed" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, pay_method)
    o.transition_to!(Order::FULFILLED)
    o.transition_to!(Order::UNCLAIMED)
    expect(o.performance.production.attendees.count).to eq(0)
  end

end

RSpec.describe TicketOrder do

  include_examples "a paid ticket order", :paid_with_cash
  include_examples "a paid ticket order", :paid_with_credit_card
  include_examples "a paid ticket order", :paid_with_membership
  include_examples "a paid ticket order", :paid_with_flex_pass
  include_examples "a paid ticket order", :paid_with_external




  it "should preserve the attendance when cancelling one of multiple reservations" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    a = o.address
    o.transition_to!(Order::FULFILLED)
    expect(o.performance.production.attendees.count).to eq(1)
    o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance=>o.performance)
    o2.address = a
    o2.save!
    o2.transition_to!(Order::FULFILLED)

    expect(o2.performance.production.attendees.uniq.size).to eq(1)

    o2.transition_to!(Order::UNCLAIMED)
    expect(o2.performance.production.attendees.uniq.size).to eq (1)
  end

  it "does not block off seats when unclaimed" do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
    o2 = o.dup
    o2.status = Order::NEW
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
    expect(OutreachTask.where(method_symbol: :ticket_confirmation).count).to eq(start_count+1)
    o.ticket_line_items.first.ticket_class.suppress_receipt=true
    o.ticket_line_items.first.ticket_class.save!
    o2 = o.dup
    o2.status = Order::NEW
    o2.ticket_line_items << o.ticket_line_items.first.dup
    o2.payment_type = FactoryBot.create(:cash_payment_type)
    o2.save!
    o2.transition_to!(Order::PROCESSED)
    expect(OutreachTask.where(method_symbol: :ticket_confirmation).count).to eq(start_count+1)

  end

  context "when overselling" do

    it "cannot processes if it would oversell a particular ticket class" do
      production = FactoryBot.create(:production, :capacity=>4)
      performance = FactoryBot.create(:performance, :production=>production)
      expect(performance.number_of_seats_left).to eq(4)
      o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance=>performance)
      o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance=>performance)
      expect(performance.number_of_seats_left).to eq(0)

      expect(lambda { order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :performance=>performance )
                  order.transition_to!(Order::PROCESSING)
                  order.errors.each {|key, data| puts data.to_yaml }
            }).to raise_error(ActiveRecord::RecordInvalid)
    end

    it "cannot processes if it would oversell a performance" do
      production = FactoryBot.create(:production, :capacity=>2)
      tc_1 = FactoryBot.create(:ticket_class, :production=>production, :class_code=>'CODEA')
      tc_2 = FactoryBot.create(:ticket_class, :production=>production, :class_code=>'CODEB')
      tc_3 = FactoryBot.create(:ticket_class, :production=>production, :class_code=>'CODEC')
      production.reload
      performance = FactoryBot.create(:performance, :production=>production)

      expect(performance.number_of_seats_left).to eq(2)
      expect(tc_1.number_left(performance)).to eq(2)
      expect(tc_2.number_left(performance)).to eq(2)
      expect(tc_3.number_left(performance)).to eq(2)

      o  = FactoryBot.create(:ticket_order, :performance=>performance)
      o.ticket_line_items << FactoryBot.build(
                                  :ticket_line_item,
                                  :ticket_class=>tc_1,
                                  :ticket_count=>1,
                                  :order=>o)
      expect(tc_1.number_left(performance)).to eq(1)
      expect(tc_2.number_left(performance)).to eq(1)
      expect(tc_2.number_left(performance)).to eq(1)

      o.ticket_line_items << FactoryBot.build(
                                  :ticket_line_item,
                                  :ticket_class=>tc_2,
                                  :ticket_count=>2,
                                  :order=>o)
      expect(tc_1.number_left(performance)).to eq(-1)
      expect(tc_2.number_left(performance)).to eq(-1)
      expect(tc_2.number_left(performance)).to eq(-1)

      #o.ticket_line_items << FactoryBot.create(
      #                            :ticket_line_item,
      #                            :ticket_class=>tc_3,
      #                            :ticket_count=>1,
      #                            :order=>o)
      expect(o.number_of_seats).to eq(3)


      expect(lambda { o.transition_to!(Order::PROCESSING) }).to raise_error(ActiveRecord::RecordInvalid)
    end

    it "can mark an order in a sold-out performance as unclaimed" do
      production = FactoryBot.create(:production, :capacity=>4)
      performance = FactoryBot.create(:performance, :production=>production)
      o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance=>performance)
      o2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :performance=>performance)
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
      payment_type.order_task_suppressions << FactoryBot.create(:order_task_suppression, task_type:o.tasks.first.type, method_name:o.tasks.first.method_symbol)
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
      followups = @ticket_order.tasks.select{|t| t.method_symbol.include?('followup')}
      expect(followups.count).to eq(0)
    end

  end

  context "when exchanging", wip:true  do

    it "allows an exchange with an external payment to a performance that is cheaper" do
      ticket_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_external)
      performance2 = ticket_order.performance.dup
      ticket_class = FactoryBot.create(:ticket_class, :ticket_price=>1.0,  class_code: 'EXCH', production:ticket_order.performance.production)
      performance2.performance_date=ticket_order.performance.performance_date+1.day
      performance2.performance_code += "A"
      performance2.save!
      performance2.reload

      exchange_order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance:performance2)
      exchange_order.ticket_line_items[0].ticket_class = ticket_class
      exchange_order.exchange_and_process_from!(ticket_order)
      amt = exchange_order.payments.inject(0.0) {|sum, p| sum += p.is_a?(PriceOverridePayment) ? p.amount : 0.0}
      expect(amt).to eq(-8.0)
      expect(exchange_order.total).to eq(2.0)
    end
  end



end
