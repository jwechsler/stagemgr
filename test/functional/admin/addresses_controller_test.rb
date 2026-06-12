require 'test_helper'

class Admin::AddressesControllerTest < ActionController::TestCase
  setup do
    @address = FactoryBot.create(:address, :full_name => "Controller Test")
  end

  test "should get index" do
    without_access_control do
      get :index
      assert_response :success
      assert_not_nil assigns(:addresses)
    end
  end

  test "should get new" do
    without_access_control do
      get :new
      assert_response :success
    end
  end

  test "should create admin_address" do
    address2 = FactoryBot.build(:address, :full_name => "New User")
    without_access_control do
      assert_difference('Address.count') do
        post :create, :address => address2.attributes
      end

      assert_redirected_to admin_address_path(assigns(:address))
    end
  end

  test "should show admin_address" do
    without_access_control do
      get :show, :id => @address.to_param
      assert_response :success
    end
  end

  test "should get edit" do
    without_access_control do
      get :edit, :id => @address.to_param
      assert_response :success
    end
  end

  test "should update admin_address" do
    without_access_control do
      put :update, :id => @address.to_param, :admin_address => @address.attributes
      assert_redirected_to admin_address_path(:id => @address.to_param)
    end
  end

  test "should destroy admin_address" do
    without_access_control do
      assert_difference('Address.count', -1) do
        delete :destroy, :id => @address.to_param
      end
      assert_redirected_to admin_addresses_path
    end
  end
end
