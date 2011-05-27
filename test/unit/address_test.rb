require 'test_helper'

class AddressTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  context "with a valid address" do
    setup do
      @new_address = Factory.create(:address, :first_name=>"Test", :last_name=>"Guy", :line1=>"1229 W Belmont Ave Unit #3", :city=>"Chicago", :state=>"IL", :zipcode=>"60657",:email=>"test@matches.com")
    end
    should "be able to parse street address" do
      @new_address.regularize!
      assert_equal "1229", @new_address.street_number
      assert_equal "BELMONT", @new_address.street
      assert_equal "AVE", @new_address.street_type
      assert_equal "3", @new_address.unit
      assert_equal "UNIT", @new_address.unit_prefix
    end
    should "automatically save parsed values" do
      @new_address.save!
      @address = Address.find(@new_address.id)
      assert_equal "1229", @address.street_number
      assert_equal "BELMONT", @address.street
      assert_equal "AVE", @address.street_type
      assert_equal "3", @address.unit
      assert_equal "UNIT", @address.unit_prefix
    end

    should "gracefully accept missing address" do
      @bad_address = Factory.create(:address, :last_name=>"hi", :line1=>'', :city=>'')
      @bad_address.save!
      assert_nil @bad_address.street_number
    end

    should "match reasonable other addresses on email first" do
      @matching_email = Factory.create(:address, :first_name=>"Jill",:last_name=>"Guy",:email=>"test@matches.com")
      @email_2 = Factory.create(:address, :first_name=>"Bill", :last_name=>"Guy",:email=>"bill@matches.com")
      assert_not_nil @new_address.find_original

    end


    should "match reasonable other addresses on first_name, last_name, street, street_number and city" do
      @matching_email = Factory.create(:address, :first_name=>"Test",:last_name=>"Guy",:email=>"jill@matches.com", :line1=>"1229 W Belmont Ave Unit #3", :city=>"Chicago", :state=>"IL", :zipcode=>"60657")
      @email_2 = Factory.create(:address, :first_name=>"Test", :last_name=>"Guy", :line1=>"1229 W Belmont Ave Unit #3", :city=>"Chicago", :state=>"IL", :zipcode=>"60657")
      assert_not_nil @email_2.find_original

    end
    should "match correctly even if regularized but never saved" do
      @matching_email = Address.new
      @matching_email.last_name = "Guy"
      @matching_email.city="chicago"
      @matching_email.line1="1229 W Belmont"
      @matching_email.regularize!
      @matching_email.first_name = "Test"
      matched = @matching_email.find_original
      assert_not_nil matched
      assert_equal "Test", matched.first_name

    end
  end

  context "with a similar address" do
    setup do
      @original_address = addresses(:jeremy)
    end
    should "merge newer contact information from a match" do
      @entered_address = Address.new
      @entered_address.last_name = "BetterName"
      @entered_address.email = "info@theaterwit.org"
      @entered_address.line2 = "2nd Floor"
      @entered_address.line1 = "1 E Madison"
      @original_address.update_from!(@entered_address)
      assert_equal "BetterName", @original_address.last_name
      assert_equal "info@theaterwit.org", @original_address.email
      assert_equal "1 E Madison", @original_address.line1
      assert_equal "2nd Floor", @original_address.line2
      assert_equal "Chicago", @original_address.city
    end

  end
end
