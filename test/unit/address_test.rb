require 'test_helper'

class AddressTest < ActiveSupport::TestCase
  context "with a valid address" do
    setup do
      @new_address = FactoryBot.create(:address, :full_name => "Test Guy", :line1 => "1229 W Belmont Ave Unit #3",
                                                 :city => "Chicago", :state => "IL", :zipcode => "60657", :email => "test@matches.com")
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
      @bad_address = FactoryBot.create(:address, :full_name => "hi", :line1 => '', :city => '')
      @bad_address.save!
      assert_nil @bad_address.street_number
    end
  end

  context "with a set of preexisting addresses" do
    setup do
      @first_customer = FactoryBot.create(:address, :full_name => "Test Guy", :line1 => "1229 W Belmont", :city => "Chicago",
                                                    :state => "IL", :zipcode => "60657", :email => "test@matches.com")
      @same_name_different_email = FactoryBot.create(:address, :full_name => "First Guy", :line1 => "1229 W Belmont",
                                                               :city => "Chicago", :state => "IL", :zipcode => "60657", :email => "test@different.com")
      @different_name_no_email = FactoryBot.create(:address, :full_name => "Second Guy", :line1 => "1229 W Belmont",
                                                             :city => "Chicago", :state => "IL", :zipcode => "60657")
    end

    should "match by name and email" do
      @new_address = Address.new
      @new_address.full_name = "Test Guy"
      @new_address.line1 = "500 W Nowhere"
      @new_address.zipcode = "60640"
      @new_address.email = "test@matches.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      assert_equal @first_customer.id, @matching.id
    end

    should "match by name and key address fields when email missing from new" do
      @new_address = Address.new
      @new_address.full_name = "Test Guy"
      @new_address.line1 = "1229 W Belmont"
      @new_address.city = "Chicago"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      assert_equal @first_customer.id, @matching.id
    end

    should "won't match without name" do
      @new_address = Address.new
      @new_address.full_name = "Other Guy"
      @new_address.line1 = "1229 W Belmont"
      @new_address.city = "Chicago"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_nil @matching
    end

    should "dont match mismatched emails" do
      @new_address = Address.new
      @new_address.full_name = "First Guy"
      @new_address.line1 = "1229 W Belmont"
      @new_address.city = "Chicago"
      @new_address.email = "random@email.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_nil @matching
    end

    should "merge missing information" do
      @new_address = Address.new
      @new_address.full_name = "Test Guy"
      @new_address.line1 = "500 W Nowhere"
      @new_address.zipcode = "60640"
      @new_address.email = "test@matches.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      @matching.update_from(@new_address)
      assert_equal "500 W Nowhere", @matching.line1
      assert_equal "60640", @matching.zipcode

      @new_address = Address.new
      @new_address.full_name = "Second Guy"
      @new_address.line1 = "1229 W Belmont"
      @new_address.city = "Chicago"
      @new_address.email = "newemail@testing.com"
      @new_address.regularize!
      @matching = @new_address.find_original
      assert_not_nil @matching
      @matching.update_from(@new_address)
      assert_equal "newemail@testing.com", @matching.email
    end
  end

  context "with a similar address" do
    setup do
      @original_address = addresses(:jeremy)
    end
    should "merge newer contact information from a match" do
      @entered_address = Address.new
      @entered_address.full_name = "BetterName"
      @entered_address.email = "info@theaterwit.org"
      @entered_address.line2 = "2nd Floor"
      @entered_address.line1 = "1 E Madison"
      @entered_address.regularize!
      @original_address.update_from(@entered_address)
      assert_equal "BetterName", @original_address.last_name
      assert_equal "info@theaterwit.org", @original_address.email
      assert_equal "1 E Madison", @original_address.line1
      assert_equal "2nd Floor", @original_address.line2
      assert_equal "Chicago", @original_address.city
    end
  end

  context "with a duplicate address entry" do
    setup do
      @address_1 = addresses(:bob_smith_1)
      @address_2 = addresses(:bob_smith_2)
      @address_3 = addresses(:john_smith)
      @address_1.save!
      @address_2.save!
      @address_2.save!
    end

    should "only use one of them for an order" do
      order = Order.new
      order.address = addresses(:bob_smith_2)
      order.link_to_address_of_record
      assert_not_nil order.address
      assert_equal addresses(:bob_smith_1).id, order.address.id
    end
    should "purge the duplicate address" do
      num_addresses = Address.all.count
      Address.purge_matched_duplicates
      assert_equal num_addresses - 1, Address.all.count
      assert_raise ActiveRecord::RecordNotFound do
        Address.find(@address_2.id)
      end
    end
  end

  context "with a new matching address and related tags" do
    setup do
      without_access_control do
        @address_1 = FactoryBot.create(:address, :full_name => "Bob Smith", :first_name => "bob", :last_name => "Smith",
                                                 :email => "bob@smith.com", :search_name => "BOB SMITH")
        @address_1.address_tags.build([{ :tag_label => "Subscription ID", :tag_value => "9393",
                                         :theater => FactoryBot.create(:theater) }])
        @address_1.save
        @address_2 = FactoryBot.create(:address, :first_name => "bob", :last_name => "Smith", :email => "bob@smith.com",
                                                 :full_name => "bob Smith")
        @address_2.address_tags.build([{ :tag_label => "Subscription ID", :tag_value => "4444",
                                         :theater => FactoryBot.create(:theater) }])
        @address_2.save
      end
    end
    should "merge the related tags" do
      merge = @address_2.find_original
      assert_equal 1, merge.address_tags.size
      merge.update_from(@address_2)
      assert_equal 2, merge.address_tags.size
      merge.save
      assert_equal 2, Address.find(@address_1.id).address_tags.size
    end
  end
end
