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
      assert_equal 1, @new_address.find_matching.size

    end


    should "match reasonable other addresses on last_name, street, street_number and city" do
      @matching_email = Factory.create(:address, :first_name=>"Jill",:last_name=>"Guy",:email=>"jill@matches.com", :line1=>"1229 W Belmont Ave Unit #3", :city=>"Chicago", :state=>"IL", :zipcode=>"60657")
      @email_2 = Factory.create(:address, :first_name=>"Bill", :last_name=>"Guy",:email=>"bill@matches.com", :line1=>"1229 W Belmont Ave Unit #3", :city=>"Chicago", :state=>"IL", :zipcode=>"60657")
      assert_equal 2, @new_address.find_matching.size

    end

    should "match correctly even if regularized but never saved" do
      @matching_email = Address.new
      @matching_email.last_name = "Guy"
      @matching_email.city="chicago"
      @matching_email.line1="1229 W Belmont"
      @matching_email.regularize!
      @matching_email.first_name = "new"
      matches = @matching_email.find_matching
      assert_equal 1, matches.size
      assert_equal "Test", matches[0].first_name

    end

  end
end
