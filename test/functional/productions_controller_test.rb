require 'test_helper'

class ProductionsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:productions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create production" do
    assert_difference('Production.count') do
      post :create, :production => { }
    end

    assert_redirected_to production_path(assigns(:production))
  end

  test "should show production" do
    get :show, :id => productions(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => productions(:one).to_param
    assert_response :success
  end

  test "should update production" do
    put :update, :id => productions(:one).to_param, :production => { }
    assert_redirected_to production_path(assigns(:production))
  end

  test "should destroy production" do
    assert_difference('Production.count', -1) do
      delete :destroy, :id => productions(:one).to_param
    end

    assert_redirected_to productions_path
  end
end
