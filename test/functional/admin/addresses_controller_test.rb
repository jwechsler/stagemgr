require 'test_helper'

class Admin::AddressesControllerTest < ActionController::TestCase
  setup do
    @address = Factory.create(:address)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:addresses)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create admin_address" do
    assert_difference('Address.count') do
      post :create, :address => @address.attributes
    end

    assert_redirected_to admin_address_path(assigns(:admin_address))
  end

  test "should show admin_address" do
    get :show, :id => @address.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @address.to_param
    assert_response :success
  end

  test "should update admin_address" do
    put :update, :id => @address.to_param, :admin_address => @address.attributes
    assert_redirected_to admin_address_path(assigns(:admin_address))
  end

  test "should destroy admin_address" do
    assert_difference('Address.count', -1) do
      delete :destroy, :id => @address.to_param
    end

    assert_redirected_to admin_addresses_path
  end
end
