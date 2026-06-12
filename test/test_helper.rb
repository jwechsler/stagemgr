ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'flexmock/test_unit'
require 'flexmock/rails'
require 'factory_bot'
# Factory.find_definitions
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def address_hash
    {
      "full_name" => "Joe Schmoe",
      "email" => "jshmoe@example.com",
      "line1" => "123 Swift St",
      "line2" => "",
      "city" => "Anytown",
      "state" => "il",
      "zipcode" => "60606",
      "phone" => "312-555-5555"
    }
  end
end
