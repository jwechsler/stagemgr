require 'test_helper'

class DonationsControllerTest < ActionController::TestCase
  test "should get new" do
    without_access_control do
      get :new
      assert_response :success
    end
  end

  test "should get confirm" do
    without_access_control do
      get :confirm
      assert_response :success
    end
  end

  test "should get show" do
    without_access_control do
      get :show
      assert_response :success
    end
  end
end
