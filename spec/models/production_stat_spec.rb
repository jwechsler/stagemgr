require "spec_helper.rb"

describe ProductionStat do
  before(:each) do
    @production = FactoryBot.create(:production)
    @production_stat = FactoryBot.create(:production_stat, :production=>@production)
  end
  it "belongs to a production" do
    production = @production
    production.production_stat.should_not be_nil
  end
  context "with ticket orders" do
    before (:each) do
      @performance1 = FactoryBot.create(:performance, :production=>@production, :performance_date=>Date.today - 1.day)
      @orders = Array.new
      3.times do
        order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>@performance1)
        order.payments.each {|payment| payment.processed_on = @performance1.to_datetime - 1.day
          payment.save
        }
        order.ticket_line_items.each do |tli|
          tli.created_at = @performance1.to_datetime - 1.day
          tli.save!
        end
        @orders << order
      end
      @performance2 = FactoryBot.create(:performance, :production=>@production, :performance_date=>Date.today + 2.days)
      2.times do
        order = FactoryBot.create(:ticket_order_for_a_pair_of_tickets_paid_with_cash, :performance=>@performance2)
        @cheap_price = order.ticket_line_items.first.ticket_class.ticket_price
        order.payments.each {|payment| payment.processed_on = @performance1.to_datetime - 1.day
          payment.save
        }
        order.ticket_line_items.each do |tli|
          tli.created_at = @performance1.to_datetime - 1.day
          tli.save!
        end
        @orders << order
      end
      order = FactoryBot.create(:ticket_order_for_an_expensive_pair_of_tickets, :performance=>@performance2)
      @expensive_price = order.ticket_line_items.first.ticket_class.ticket_price
      order.payments.each {|payment| payment.processed_on = @performance2.to_datetime - 1.day
          payment.save
        }
      order.ticket_line_items.each do |tli|
          tli.created_at = @performance2.to_datetime - 1.day
          tli.save!
        end

      @orders << order
      @production.update_stats
    end
    it "should aggregate average ticket price for settled orders" do

      stat = @production.production_stat
      stat.average_ticket_price.should eq(@orders.inject(0) {|sum, o| sum + (o.settled? ? o.total : 0)} / @orders.inject(0) {|sum,o| sum + o.number_of_tickets_of_all_payments})
      stat.average_ticket_price.should eq(@cheap_price)
    end
    it "should total the number of tickets sold for settled orders" do
      stat = @production.production_stat
      stat.number_of_tickets.should eq(10)
      stat.number_of_tickets.should eq(@orders.inject(0) {|sum,o| sum + (o.settled? ? o.number_of_tickets_of_all_payments : 0)})
    end

    it "should calculate advance sales and seats sold by date" do
      stat = @production.production_stat
      advance = stat.snapshot(@performance1.performance_date - 1.day)
      advance.advance_sales.should eq(50)
      advance.advance_seats.should eq(10)
      advance = stat.snapshot(@performance2.performance_date - 1.day)
      advance.advance_sales.should eq(20)
      advance.advance_seats.should eq(4)
    end

  end
end