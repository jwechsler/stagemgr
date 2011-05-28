require 'test_helper'

class AddressTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  context "with a valid address" do
    setup do
      @new_address = Factory.create(:address, :first_name=>"Test", :last_name=>"Guy", :line1=>"1229 W Belmont Ave Unit #3", :city=>"Chicago", :state=>"IL", :zipcode=>"60657", :email=>"test@matches.com")
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
  end

  context "with a set of preexisting addresses" do

    setup do
      @first_customer = Factory.create(:address, :first_name=>"First", :last_name=>"Guy", :line1=>"1229 W Belmont", :city=>"Chicago", :state=>"IL", :zipcode=>"60657", :email=>"test@matches.com")
      @same_name_different_email = Factory.create(:address, :first_name=>"First", :last_name=>"Guy", :line1=>"1229 W Belmont", :city=>"Chicago", :state=>"IL", :zipcode=>"60657", :email=>"test@different.com")
      @different_name_no_email = Factory.create(:address, :first_name=>"Second", :last_name=>"Guy", :line1=>"1229 W Belmont", :city=>"Chicago", :state=>"IL", :zipcode=>"60657")

    end

    should "match by name and email" do
      @new_address = Address.new
      @new_address.first_name = "First"
      @new_address.last_name="Guy"
      @new_address.line1="500 W Nowhere"
      @new_address.zipcode="60640"
      @new_address.email="test@matches.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      assert_equal @first_customer.id, @matching.id
    end

    should "match by name and key address fields when email missing from new" do
      @new_address = Address.new
      @new_address.first_name = "First"
      @new_address.last_name="Guy"
      @new_address.line1="1229 W Belmont"
      @new_address.city="Chicago"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      assert_equal @first_customer.id, @matching.id
    end

    should "won't match without name" do
      @new_address = Address.new
      @new_address.first_name = "Other"
      @new_address.last_name="Guy"
      @new_address.line1="1229 W Belmont"
      @new_address.city="Chicago"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_nil @matching
    end

    should "dont match mismatched emails" do
      @new_address = Address.new
      @new_address.first_name = "First"
      @new_address.last_name="Guy"
      @new_address.line1="1229 W Belmont"
      @new_address.city="Chicago"
      @new_address.email="random@email.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_nil @matching

    end

    should "merge missing information" do
      @new_address = Address.new
      @new_address.first_name = "First"
      @new_address.last_name="Guy"
      @new_address.line1="500 W Nowhere"
      @new_address.zipcode="60640"
      @new_address.email="test@matches.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      @matching.update_from!(@new_address)
      assert_equal "500 W Nowhere", @matching.line1
      assert_equal "60640", @matching.zipcode

      @new_address = Address.new
      @new_address.first_name = "Second"
      @new_address.last_name="Guy"
      @new_address.line1="1229 W Belmont"
      @new_address.city="Chicago"
      @new_address.email="newemail@testing.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      @matching.update_from!(@new_address)
      assert_equal "newemail@testing.com", @matching.email

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
