require "spec_helper.rb"

describe "an exchanged ticket order" do
  it "should have an offset payment" do
    performance = FactoryBot.create(:performance)
    performance2 = FactoryBot.create(:performance)
    original_order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>performance)
    exchange_order = FactoryBot.create(:ticket_order, :performance=>performance2)
    ticket_line_item = original_order.ticket_line_items.first.dup
    ticket_line_item.ticket_class = performance2.ticket_class_allocations.first.ticket_class
    exchange_order.ticket_line_items << ticket_line_item
    exchange_order.exchange_and_process_from! original_order
    expect(exchange_order.payments.size).to eq(1)
    expect(original_order.payments.size).to eq(2)
    expect(original_order.status).to eq(Order::EXCHANGED)
    expect(original_order.total).to eq(0.0)
    expect(exchange_order.total).to eq(10.0)
    original_order.payments.select {|p| p.is_a? ExchangePayment}.each{ |p|
      expect(p.payment_id).to eq(exchange_order.payments.first.id)}
    exchange_order.payments.each {|p|
      expect(p.payment_id).to be_in(original_order.payments.map{|op| op.id})}
  end
end

describe "a ticket order" do

  it "can be refunded" do
    o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    expect(o.total).to be > 0
    o.refund!
    expect(o.total).to eq(0)
  end

  it "should mark its holder has having attended the production when fulfilled" do
    original_order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    original_order.transition_to!(Order::FULFILLED)
    original_order.performance.production.attendees.count.should == 1
  end

  it "should unmark the holder has having attended when refunded" do
    o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    production = o.performance.production
    o.refund!
    expect(o.performance.production.attendees.size).to eq(0)
  end

   it "should unmark the holder has having attended when unclaimed" do
    o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o.transition_to!(Order::FULFILLED)
    o.transition_to!(Order::UNCLAIMED)
    production = o.performance.production
    o.refund!
    expect(o.performance.production.attendees.count).to eq(0)
  end

  it "should preserve the attendance when cancelling one of multiple reservations" do
    o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    a = o.address
    o.transition_to!(Order::FULFILLED)
    expect(o.performance.production.attendees.count).to eq(1)
    o2 = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>o.performance)
    o2.address = a
    o2.save!
    o2.transition_to!(Order::FULFILLED)

    expect(o2.performance.production.attendees.uniq.size).to eq(1)

    o2.transition_to!(Order::UNCLAIMED)
    expect(o2.performance.production.attendees.uniq.size).to eq (1)
  end

  it "does not block off seats when unclaimed" do
    Authorization.ignore_access_control(true)
    o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
    o2 = o.dup
    o2.status = Order::NEW
    o2.save!
    o2.ticket_line_items << o.ticket_line_items.first.dup
    o2.payment_type = FactoryBot.create(:cash_payment_type)
    o2.transition_to!(Order::PROCESSED)
    o2.performance.production.capacity = 10
    o2.performance.production.save!

    o2.performance.reload
    o2.performance.number_of_seats_left.should == 6
    o2.transition_to!(Order::FULFILLED)
    o2.performance.number_of_seats_left.should == 6
    o2.transition_to!(Order::UNCLAIMED)
    o2.performance.reload
    o2.performance.number_of_seats_left.should == 8
  end

  context "when overselling" do
    before (:each) do
      Authorization.ignore_access_control
    end

    after (:each) do
      Authorization.ignore_access_control(false)
    end

    it "cannot processes if it would oversell a particular ticket class" do
      production = FactoryBot.create(:production, :capacity=>4)
      performance = FactoryBot.create(:performance, :production=>production)
      performance.number_of_seats_left.should eq(4)
      o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>performance)
      o2 = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>performance)
      performance.number_of_seats_left.should eq(0)

      lambda { order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets, :performance=>performance )
                  order.transition_to!(Order::PROCESSING)
            }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "cannot processes if it would oversell a performance" do
      Authorization.ignore_access_control
      production = FactoryBot.create(:production, :capacity=>2)
      tc_1 = FactoryBot.create(:ticket_class, :production=>production, :class_code=>'CODEA')
      tc_2 = FactoryBot.create(:ticket_class, :production=>production, :class_code=>'CODEB')
      tc_3 = FactoryBot.create(:ticket_class, :production=>production, :class_code=>'CODEC')
      production.reload
      performance = FactoryBot.create(:performance, :production=>production)

      performance.number_of_seats_left.should eq(2)
      tc_1.number_left(performance).should eq(2)
      tc_2.number_left(performance).should eq(2)
      tc_3.number_left(performance).should eq(2)

      o  = FactoryBot.create(:ticket_order, :performance=>performance)
      o.ticket_line_items << FactoryBot.build(
                                  :ticket_line_item,
                                  :ticket_class=>tc_1,
                                  :ticket_count=>1,
                                  :order=>o)
      tc_1.number_left(performance).should eq(1)
      tc_2.number_left(performance).should eq(1)
      tc_2.number_left(performance).should eq(1)

      o.ticket_line_items << FactoryBot.build(
                                  :ticket_line_item,
                                  :ticket_class=>tc_2,
                                  :ticket_count=>2,
                                  :order=>o)
      tc_1.number_left(performance).should eq(-1)
      tc_2.number_left(performance).should eq(-1)
      tc_2.number_left(performance).should eq(-1)

      #o.ticket_line_items << FactoryBot.create(
      #                            :ticket_line_item,
      #                            :ticket_class=>tc_3,
      #                            :ticket_count=>1,
      #                            :order=>o)
      o.number_of_seats.should eq(3)


      lambda { o.transition_to!(Order::PROCESSING) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "can mark an order in a sold-out performance as unclaimed" do
      production = FactoryBot.create(:production, :capacity=>4)
      performance = FactoryBot.create(:performance, :production=>production)
      o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>performance)
      o2 = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>performance)
      o.transition_to!(Order::FULFILLED)
      o2.transition_to!(Order::FULFILLED)
      performance.number_of_seats_left.should eq(0)
      o.transition_to!(Order::UNCLAIMED)
      performance.number_of_seats_left.should eq(2)
    end

    it "creates tasks for asynchronous post-operation, except where prohibited by the payment type" do
      o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
      task_count = o.tasks.count
      task_count.should be > 0
      payment_type = o.payment_type
      payment_type.order_task_suppressions << FactoryBot.create(:order_task_suppression, task_type:o.tasks.first.type, method_name:o.tasks.first.method_symbol)
      payment_type.save
      o2 = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
      o2.tasks.count.should eq(task_count)
      t = o2.tasks.first
      t.run!
      t.status.should eq('Cancelled')

    end

    it "can be held under a different name but not under an email" do

      o = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
      o.hold_under = "Another Name"
      expect(o.save).to equal(true)
      expect(o.hold_under).to eq('Another Name')
      o.hold_under = 'bad@email.com'
      expect(o.save).to equal(false)
    end

  end


  context "to an event that is not a performance" do
    before(:each) do
      @ticket_order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash)
      @ticket_order.performance.production.production_class = Production::CLASS
      @ticket_order.performance.production.save
    end

    it "sends a simplified confirmation email" do
      Authorization.ignore_access_control(true)
      mail = OrderMailer.ticket_confirmation(@ticket_order)
      expect(mail.body.encoded).not_to match("Dining")
      expect(mail.body.encoded).not_to match("seating")
      expect(mail.body.encoded).to match("reservation")
    end

    it "does not send an automatic followup" do
      followups = @ticket_order.tasks.select{|t| t.method_symbol.include?('followup')}
      followups.count.should == 0
    end

  end
end
