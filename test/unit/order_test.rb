require 'test_helper'
require 'exceptions'

class OrderTest < ActiveSupport::TestCase
  self.use_instantiated_fixtures = true

  context 'with a flexpass order' do
    setup do
      @cash_payment_type = FactoryBot.create(:cash_payment_type)
      @flex_pass_payment_type = FactoryBot.create(:flex_pass_payment_type)
      @order = FactoryBot.create(:flex_pass_order, :address => addresses(:jeremy), :payment_type => @cash_payment_type)

      @order.build_flex_pass_line_item(:flex_pass_offer => flex_pass_offers(:flexpass_5_offer), :ticket_count => 1)
      @order.transition_to!(Order::PROCESSING)
      @order.transition_to!(Order::PROCESSED)
      @order.transition_to!(Order::FULFILLED)
      assert_equal 1, @order.payments.count
      assert_equal Order::FULFILLED, @order.status
    end
    should 'generate a flex pass' do
      assert_not_nil @order.flex_pass_line_item.flex_pass
      assert_not_nil @order.flex_pass_line_item.flex_pass.code
    end
    should 'allow you to buy a ticket' do
      flex_pass = @order.flex_pass_line_item.flex_pass
      @ticket_order = FactoryBot.create(:ticket_order, :address => addresses(:jeremy),
                                                       :payment_type => @flex_pass_payment_type,
                                                       :performance => performances(:macbeth_opening))
      @ticket_order.ticket_line_items.build(:ticket_class => ticket_classes(:macbeth_general_admission),
                                            :ticket_count => 1)
      @ticket_order.flex_pass_code = flex_pass.code
      @ticket_order.transition_to!(Order::PROCESSING)
      @ticket_order.transition_to!(Order::PROCESSED)
      assert_equal 1, @ticket_order.flex_pass_payments.count
      assert_equal flex_pass, @ticket_order.flex_pass_payments[0].flex_pass
    end

    should 'not allow you to buy too many tickets' do
      flex_pass = @order.flex_pass_line_item.flex_pass
      @ticket_order = FactoryBot.create(:ticket_order, :address => addresses(:jeremy),
                                                       :payment_type => @flex_pass_payment_type,
                                                       :performance => performances(:macbeth_opening))
      @ticket_order.ticket_line_items.build(:ticket_class => ticket_classes(:macbeth_general_admission),
                                            :ticket_count => 6)
      @ticket_order.flex_pass_code = flex_pass.code

      assert_raises ActiveRecord::RecordInvalid do
        @ticket_order.transition_to!(Order::PROCESSING)
        @ticket_order.transition_to!(Order::PROCESSED)
      end
    end
  end
  context 'with an existing order' do
    setup do
      without_access_control do
        @credit_card_payment_type = FactoryBot.create(:credit_card_payment_type)
        @cash_payment_type = FactoryBot.create(:cash_payment_type)
        @production = FactoryBot.create(:production, :capacity => 10)
        @ticket_class = FactoryBot.create(:ticket_class, :production => @production, :class_code => 'ABC',
                                                         :ticket_price => 3)
        @performance = FactoryBot.create(:performance, :production => @production)
        @production2 = FactoryBot.create(:production, :capacity => 10)
        @ticket_class2 = FactoryBot.create(:ticket_class, :production => @production2, :class_code => 'ABC',
                                                          :ticket_price => 5)
        @performance2 = FactoryBot.create(:performance, :production => @production2)
        @original_order = FactoryBot.create(:ticket_order, :address => addresses(:jeremy), :performance => @performance,
                                                           :payment_type => @cash_payment_type)
        @cash_payment_type = FactoryBot.create(:cash_payment_type)
        @original_order.ticket_line_items.build(:ticket_class => @ticket_class, :ticket_count => 1)
        @original_order.payment_type = @cash_payment_type
        @original_order.performance = @performance
        @original_order.transition_to!(Order::PROCESSING)
        @original_order.transition_to!(Order::PROCESSED)
        assert_equal 1, @original_order.payments.count
        assert @original_order.payments(true).to_a.sum { |p| p.amount } > 0
      end
    end

    should 'be able to exchange order' do
      without_access_control do
        @exchange_order = TicketOrder.new(:status => Order::NEW, :performance => @performance2,
                                          :payment_type => @cash_payment_type)
        @exchange_order.ticket_line_items.build(:order => @exchange_order, :ticket_class => @ticket_class2,
                                                :ticket_count => 1).save!
        @exchange_order.exchange_and_process_from! @original_order
        assert_equal 0, @original_order.payments(true).to_a.sum { |p| p.amount }
        assert_equal 5, @exchange_order.total
        assert_equal 5, @exchange_order.payments(true).to_a.sum { |p| p.amount }
        assert_equal Order::EXCHANGED, @original_order.status
        assert_equal Order::PROCESSED, @exchange_order.status
      end
    end
  end
  context 'for nested attributes' do
    setup do
      without_access_control do
        @credit_card_payment_type = FactoryBot.create(:credit_card_payment_type)
        @cash_payment_type = FactoryBot.create(:cash_payment_type)

        @production = FactoryBot.create(:production, :capacity => 10)
        @ticket_class = FactoryBot.create(:ticket_class, :production => @production, :class_code => 'ABC',
                                                         :ticket_price => 3, :auto_attach => true)
        @performance = FactoryBot.create(:performance, :production => @production)
        @production2 = FactoryBot.create(:production, :capacity => 10)
        @ticket_class2 = FactoryBot.create(:ticket_class, :production => @production2, :class_code => 'ABC',
                                                          :ticket_price => 5, :auto_attach => true)
        @performance2 = FactoryBot.create(:performance, :production => @production2)
      end
    end

    should 'be able to create entire hierarchy in new' do
      without_access_control do
        params_order = {
          "production_code" => @production.production_code,
          "ticket_line_items_attributes" => {
            "0" => {
              "ticket_class_id" => @ticket_class.id,
              "ticket_count" => "2"
            }
          },
          "address_attributes" => {
            "city" => "Metropolis",
            "line1" => "123 Swift St",
            "line2" => "",
            "zipcode" => "90210",
            "full_name" => "Test",
            "state" => "NC",
            "first_name" => ""
          },
          "notes" => "",
          "performance_code" => @performance.performance_code,
          "payment_type_id" => @credit_card_payment_type.id,
          "credit_card_expiration_month" => '09',
          "credit_card_expiration_year" => '2014',
          "credit_card_verification_number" => '123',
          "credit_card_number" => '123412341234',
          "credit_card_type" => 'American Express',
          "status" => Order::NEW
        }
        order = TicketOrder.create!(params_order)
      end
    end

    should 'correctly scope ticket_class code to production' do
      without_access_control do
        params_order = {
          "production_code" => @production2.production_code,
          "ticket_line_items_attributes" => {
            "0" => {
              "ticket_class_id" => @ticket_class2.id,
              "ticket_count" => "1"
            }
          },
          "address_attributes" => {
            "city" => "Metropolis",
            "line1" => "123 Swift St",
            "line2" => "",
            "zipcode" => "90210",
            "full_name" => "Test",
            "state" => "NC",
            "first_name" => ""
          },
          "notes" => "",
          "performance_code" => @performance2.performance_code,
          "payment_type_id" => @credit_card_payment_type.id,
          "credit_card_expiration_month" => '09',
          "credit_card_expiration_year" => '2014',
          "credit_card_verification_number" => '123',
          "credit_card_number" => '4111111111111111',
          "credit_card_type" => 'Visa',
          "marketing_source" => "Email",
          "credit_card_confirmation_code" => "",
          "status" => Order::NEW
        }
        order = TicketOrder.create!(params_order)
        assert_equal 5, TicketOrder.find(order.id).ticket_line_items.first.total
      end
    end

    should 'accept address and performance in create' do
      without_access_control do
        @credit_card_payment_type = FactoryBot.create(:credit_card_payment_type)
        @cash_payment_type = FactoryBot.create(:cash_payment_type)

        @production = FactoryBot.create(:production, :capacity => 10)
        @ticket_class = FactoryBot.create(:ticket_class, :production => @production)
        @performance = FactoryBot.create(:performance, :production => @production)
        @address = addresses(:jeremy)
        assert_not_nil @address
        TicketOrder.create!(:address => @address, :performance => @performance, :status => Order::NEW,
                            :payment_type => @cash_payment_type)
      end
    end
  end
  context 'with a production of capacity of 10 and a performance' do
    setup do
      without_access_control do
        @cash_payment_type = FactoryBot.create(:cash_payment_type)
        @production = FactoryBot.build(:production)
        @production.capacity = 10
        @production.save
        @ticket_class = FactoryBot.create(:ticket_class, :production => @production)
        @comp_ticket = FactoryBot.create(:ticket_class, :production => @production, :class_code => "COMP",
                                                        :ticket_price => 0.0)
        @performance = FactoryBot.create(:performance, :production => @production)
        @address = addresses(:jeremy)
      end
    end

    should "A held order reduces the quantity of tickets available for the performance" do
      without_access_control do
        o = TicketOrder.create!(:status => Order::HOLD, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
        li = o.ticket_line_items.create!(:ticket_class => @production.ticket_classes.first, :ticket_count => 5)
        assert_equal 5, @performance.number_of_seats_left
      end
    end

    should "A processed order reduces the quantity of tickets available for the performance" do
      without_access_control do
        o = TicketOrder.create!(:status => Order::PROCESSED, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
        li = o.ticket_line_items.create!(:ticket_class => @production.ticket_classes.first, :ticket_count => 5)
        assert_equal 5, @performance.number_of_seats_left
      end
    end

    should "A canceled order does not reduces the quantity of tickets available for the performance" do
      without_access_control do
        o = FactoryBot.create(:ticket_order, :performance => @performance, :payment_type => @cash_payment_type)
        li = o.ticket_line_items.create!(:ticket_class => @comp_ticket, :ticket_count => 5)
        o.transition_to!(Order::PROCESSED)
        o.cancel!
        assert_equal 10, @performance.number_of_seats_left
      end
    end

    should "A refunded order does not reduces the quantity of tickets available for the performance" do
      without_access_control do
        o = FactoryBot.create(:ticket_order, :performance => @performance, :payment_type => @cash_payment_type)
        li = o.ticket_line_items.create!(:ticket_class => @production.ticket_classes.first, :ticket_count => 5)
        o.transition_to!(Order::PROCESSED)
        o.refund!
        assert_equal 10, @performance.number_of_seats_left
      end
    end

    should "available tickets for a performance cannot drop below 0" do
      without_access_control do
        o = TicketOrder.create!(:status => Order::HOLD, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
        li = o.ticket_line_items.build(:ticket_class => @production.ticket_classes.first, :ticket_count => 11)
        assert_false li.save
      end
    end

    should "orders can be in Held, Canceled, Processed, or Refunded status" do
      without_access_control do
        o = TicketOrder.create!(:status => Order::HOLD, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
        o = TicketOrder.create!(:status => Order::CANCELED, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
        o = TicketOrder.create!(:status => Order::PROCESSED, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
        o = TicketOrder.create!(:status => Order::REFUNDED, :address => @address, :performance => @performance,
                                :payment_type => @cash_payment_type)
      end
    end
  end

  context "with a membership offer" do
    setup do
      @address = addresses(:jeremy)
      @offer = FactoryBot.create(:membership_offer, :name => "Test Offer", :tickets_per_performance => 1,
                                                    :use_ticket_class_code => "MEMBER")
    end

    should "create a valid new membership order" do
      @order = MembershipOrder.create!(:status => Order::NEW, :address => @address)
      @order.membership_offer = @offer
      @order.payments << FactoryBot.create(:cash_payment, :amount => 15)
      @order.transition_to!(Order::PROCESSING)
      @order.save!
      assert_not_nil(@order.membership)
      membership = Membership.find_by_member_code(@order.membership.member_code)
      assert_not_nil(membership)
      assert_not_nil(membership.member_code)
      assert_not_nil(membership.address)
      assert_equal(@order.address, membership.address)
      assert_equal(@offer, membership.membership_offer)
    end
  end

  context "with an existing membership" do
    setup do
      @membership_payment_type = FactoryBot.create :membership_payment_type
      @address = addresses(:jeremy)
      @offer = FactoryBot.create(:membership_offer, :name => "Test Offer",
                                                    :use_ticket_class_code => "MEMBER", :tickets_per_performance => 1)

      @order = MembershipOrder.create!(:status => Order::NEW, :address => @address)
      @order.membership_offer = @offer
      @order.payments << FactoryBot.create(:cash_payment, :amount => 15)
      @order.transition_to!(Order::PROCESSING)
      @order.membership.status = Membership::ACTIVE
      @order.membership.number_cycles_completed = 1
      @order.membership.save
    end
    should "allow you to purchase a ticket for a particular performance" do
      code = @order.membership.member_code

      o = TicketOrder.create(:status => Order::NEW, :address => @address, :performance => performances(:macbeth_opening),
                             :payment_type => @membership_payment_type, :member_code => @order.membership.member_code)
      o.ticket_line_items.create!(:ticket_class => ticket_classes(:macbeth_general_admission), :ticket_count => 1)
      assert_not_nil(o.address.email)
      assert_not_nil(@order.membership.address)
      o.transition_to!(Order::PROCESSING)
      o.transition_to!(Order::PROCESSED)
      assert_equal(o.status, Order::PROCESSED)
      assert_equal(1, o.ticket_line_items.select { |li|
        li.ticket_class.class_code == 'MEMBER'
      }.map { |li| li.ticket_count }.sum)
      assert_equal('MEMBER', o.ticket_line_items.first.ticket_class.class_code)
    end
    should "only allow you to purchase the specified number of tickets for that offer/performance" do
      code = @order.membership.member_code
      o = TicketOrder.create(:status => Order::NEW, :address => @address, :performance => performances(:macbeth_opening),
                             :payment_type => @membership_payment_type, :member_code => @order.membership.member_code)
      o.ticket_line_items.create!(:ticket_class => ticket_classes(:macbeth_general_admission), :ticket_count => 2)
      assert_not_nil(o.address.email)
      assert_not_nil(@order.membership.address)
      o.transition_to!(Order::PROCESSING)
      assert_raise(Exceptions::TooManyTicketsForMembership) {
        o.transition_to!(Order::PROCESSED)
      }
    end
    should "only allow you to purchase the specified number of tickets across orders for a performance" do
      code = @order.membership.member_code
      o = TicketOrder.create(:status => Order::NEW, :address => @address, :performance => performances(:macbeth_opening),
                             :payment_type => @membership_payment_type, :member_code => @order.membership.member_code)
      o.ticket_line_items.create!(:ticket_class => ticket_classes(:macbeth_general_admission), :ticket_count => 1)
      assert_not_nil(o.address.email)
      assert_not_nil(@order.membership.address)
      o.transition_to!(Order::PROCESSING)
      o.transition_to!(Order::PROCESSED)
      code = @order.membership.member_code
      o = TicketOrder.create(:status => Order::NEW, :address => @address, :performance => performances(:macbeth_opening),
                             :payment_type => @membership_payment_type, :member_code => @order.membership.member_code)
      o.ticket_line_items.create!(:ticket_class => ticket_classes(:macbeth_general_admission), :ticket_count => 1)
      assert_not_nil(o.address.email)
      assert_not_nil(@order.membership.address)
      o.transition_to!(Order::PROCESSING)
      assert_raise(Exceptions::TooManyTicketsForMembership) {
        o.transition_to!(Order::PROCESSED)
      }
    end
  end
end
