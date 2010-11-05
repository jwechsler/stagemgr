require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  context 'with an existing order' do
    setup do
      @production = Factory.create(:production, :capacity=>10)
      @ticket_class = Factory.create(:ticket_class, :production=>@production, :class_code=>'ABC', :ticket_price=>3)
      @performance = Factory.create(:performance, :production=>@production)
      @production2 = Factory.create(:production, :capacity=>10)
      @ticket_class2 = Factory.create(:ticket_class, :production=>@production2, :class_code=>'ABC', :ticket_price=>5)
      @performance2 = Factory.create(:performance, :production=>@production2)
      @original_order = Factory.create(:order)
      @original_order.ticket_line_items.build(:ticket_class=>@ticket_class, :ticket_count=>1)
      @original_order.payment_type = Order::CASH
      @original_order.performance = @performance
      @original_order.transition_to!(Order::PROCESSING)
      @original_order.transition_to!(Order::PROCESSED)
      assert_equal 1, @original_order.payments.count
      assert @original_order.payments(true).to_a.sum{|p|p.amount} > 0
    end
    
    should 'be able to exchange order' do
      @exchange_order = Order.new(:status=>Order::NEW, :performance=>@performance2, :payment_type=>Order::CASH)
      @exchange_order.ticket_line_items.build(:order=>@exchange_order, :ticket_class=>@ticket_class2, :ticket_count=>1).save!
      @exchange_order.exchange_and_process_from! @original_order
      assert_equal 0, @original_order.payments(true).to_a.sum{|p|p.amount}
      assert_equal 5, @exchange_order.total(true)
      assert_equal 5, @exchange_order.payments(true).to_a.sum{|p|p.amount}
      assert_equal Order::EXCHANGED, @original_order.status
      assert_equal Order::PROCESSED, @exchange_order.status
    end
  end
  context 'for nested attributes' do
    setup do
      @production = Factory.create(:production, :capacity=>10)
      @ticket_class = Factory.create(:ticket_class, :production=>@production, :class_code=>'ABC', :ticket_price=>3)
      @performance = Factory.create(:performance, :production=>@production)
      @production2 = Factory.create(:production, :capacity=>10)
      @ticket_class2 = Factory.create(:ticket_class, :production=>@production2, :class_code=>'ABC', :ticket_price=>5)
      @performance2 = Factory.create(:performance, :production=>@production2)
    end
    
    should 'be able to create entire hierarchy in new' do
      params_order = {
        "production_code"=>@production.production_code, 
        "ticket_line_items_attributes"=>{
          "0"=>{
            "ticket_class_code"=>@ticket_class.class_code, 
            "ticket_count"=>"2"
          }
        }, 
        "address_attributes"=>{
          "city"=>"Metropolis", 
          "line1"=>"123 Swift St", 
          "line2"=>"", 
          "zipcode"=>"90210", 
          "last_name"=>"", 
          "state"=>"NC", 
          "first_name"=>""
        },
        "notes"=>"", 
        "performance_code"=>@performance.performance_code, 
        "referral_code"=>"", 
        "payment_type"=>"Credit Card",
        "credit_card_expiration_month"=>'09',
        "credit_card_expiration_year"=>'2014',
        "credit_card_verification_number"=>'123',
        "credit_card_number"=>'123412341234',
        "credit_card_type"=>'American Express'
      }
      order = Order.create!(params_order)
    end
    
    should 'correctly scope ticket_class code to production' do
      params_order = {
        "production_code"=>@production2.production_code, 
        "ticket_line_items_attributes"=>{
          "0"=>{
            "ticket_class_code"=>@ticket_class2.class_code, 
            "ticket_count"=>"1"
          }
        }, 
        "address_attributes"=>{
          "city"=>"Metropolis", 
          "line1"=>"123 Swift St", 
          "line2"=>"", 
          "zipcode"=>"90210", 
          "last_name"=>"", 
          "state"=>"NC", 
          "first_name"=>""
        }, 
        "notes"=>"", 
        "performance_code"=>@performance2.performance_code, 
        "referral_code"=>"", 
        "payment_type"=>"Credit Card",
        "credit_card_expiration_month"=>'09',
        "credit_card_expiration_year"=>'2014',
        "credit_card_verification_number"=>'123',
        "credit_card_number"=>'4111111111111111',
        "credit_card_type"=>'Visa'
      }
      order = Order.create!(params_order)
      assert_equal 5, Order.find(order.id).ticket_line_items.first.total
    end
    
    should 'accept address and performance in create' do
      @production = Factory.create(:production, :capacity=>10)
      @ticket_class = Factory.create(:ticket_class, :production=>@production)
      @performance = Factory.create(:performance, :production=>@production)
      @address = Factory.create(:address)
      assert_not_nil @address
      Order.create!(:address=>@address,:performance=>@performance)      
    end
  end
  context 'with a production of capacity of 10 and a performance' do
    setup do
      @production = Factory.create(:production, :capacity=>10)
      @ticket_class = Factory.create(:ticket_class, :production=>@production)
      @performance = Factory.create(:performance, :production=>@production)
      @address = Factory.create(:address)
    end
      
    should "A held order reduces the quantity of tickets available for the performance" do
      o = Order.create!(:status=>Order::HOLD,:address=>@address, :performance=>@performance)
      li = o.ticket_line_items.create!(:ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 5, @performance.number_of_tickets_left
    end

    should "A processed order reduces the quantity of tickets available for the performance" do
      o = Order.create!(:status=>Order::PROCESSED,:address=>@address, :performance=>@performance)
      li = o.ticket_line_items.create!(:ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 5, @performance.number_of_tickets_left
    end

    should "A canceled order does not reduce the quantity of tickets available for the performance" do
      o = Order.create!(:status=>Order::CANCELED,:address=>@address, :performance=>@performance)
      li = o.ticket_line_items.create!(:ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 10, @performance.number_of_tickets_left
    end

    should "A refunded order does not reduce the quantity of tickets available for the performance" do
      o = Order.create!(:status=>Order::REFUNDED,:address=>@address, :performance=>@performance)
      li = o.ticket_line_items.create!(:ticket_class=>@production.ticket_classes.first, :ticket_count=>5)
      assert 10, @performance.number_of_tickets_left
    end

    should "available tickets for a performance cannot drop below 0" do
      o = Order.create!(:status=>Order::HOLD,:address=>@address, :performance=>@performance)
      li = o.ticket_line_items.build(:ticket_class=>@production.ticket_classes.first, :ticket_count=>11)
      assert_false li.save
    end

    should "orders can be in Held, Canceled, Processed, or Refunded status" do
      o = Order.create!(:status=>Order::HOLD,:address=>@address, :performance=>@performance)
      o = Order.create!(:status=>Order::CANCELED,:address=>@address, :performance=>@performance)
      o = Order.create!(:status=>Order::PROCESSED,:address=>@address, :performance=>@performance)
      o = Order.create!(:status=>Order::REFUNDED,:address=>@address, :performance=>@performance)
    end
  end
end
