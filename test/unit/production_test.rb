require 'test_helper'

class ProductionTest < ActiveSupport::TestCase

  context "with a sample production and two default ticket classes" do
    setup do
      without_access_control do
        @default_ticket_class1 = Factory.create(:default_ticket_class, :class_code=>'GEN', :class_name=>'Test General', :ticket_type=>'Fixed', :ticket_price=>20, :ticketing_fee=>1)
        @default_ticket_class2 = Factory.create(:default_ticket_class, :class_code=>'COMP', :class_name=>'Test Comp', :ticket_type=>'Fixed', :ticket_price=>0, :ticketing_fee=>0)
        @production = Factory.create(:production, :theater=>theaters(:theater_wit))
      end
    end
    should "have defaults assigned when created" do
      without_access_control do
        assert_equal(2, @production.ticket_classes.size)
      end

    end

  end

end