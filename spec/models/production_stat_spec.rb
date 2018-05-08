require "spec_helper.rb"

describe ProductionStat do
  before(:each) do
    @production = FactoryBot.create(:production)
    @production_stat = FactoryBot.create(:production_stat, :production=>@production)
  end
  it "belongs to a production" do
    production = @production
    expect(production.production_stat).not_to be_nil
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
        order.payments.each {|payment| payment.processed_on = @performance2.to_datetime - 1.day
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
          payment.save!
        }
      order.ticket_line_items.each do |tli|
          tli.created_at = @performance1.to_datetime - 1.day
          tli.save!
        end

      @orders << order

      @production.update_stats

    end

    it "should aggregate average ticket price for settled orders" do

      stat = @production.production_stat
      average_price = @orders.inject(0) {|sum, o| sum + (o.settled? ? o.total : 0)} /
        @orders.inject(0) {|sum,o| sum + o.number_of_tickets_of_all_payments}
      expect(stat.average_ticket_price).to eq(average_price)
      expect(stat.average_ticket_price).to eq(@cheap_price)
    end

    it "should total the number of tickets sold for settled orders" do
      stat = @production.production_stat
      expect(stat.number_of_tickets).to eq(10)
      expect(stat.number_of_tickets).to eq(@orders.inject(0) {|sum,o| sum + (o.settled? ? o.number_of_tickets_of_all_payments : 0)})
    end

    it "should calculate advance sales and seats sold by date" do
      stat = @production.production_stat
      advance = stat.snapshot(@performance1.performance_date - 1.day)
      expect(advance.advance_sales).to eq(30)
      expect(advance.advance_seats).to eq(10)
      advance = stat.snapshot(@performance2.performance_date - 1.day)
      expect(advance.advance_sales).to eq(20)
      expect(advance.advance_seats).to eq(4)
    end

  end
end