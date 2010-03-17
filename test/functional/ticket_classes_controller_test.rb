require 'test_helper'

class TicketClassesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:ticket_classes)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create ticket_class" do
    assert_difference('TicketClass.count') do
      post :create, :ticket_class => { }
    end

    assert_redirected_to ticket_class_path(assigns(:ticket_class))
  end

  test "should show ticket_class" do
    get :show, :id => ticket_classes(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => ticket_classes(:one).to_param
    assert_response :success
  end

  test "should update ticket_class" do
    put :update, :id => ticket_classes(:one).to_param, :ticket_class => { }
    assert_redirected_to ticket_class_path(assigns(:ticket_class))
  end

  test "should destroy ticket_class" do
    assert_difference('TicketClass.count', -1) do
      delete :destroy, :id => ticket_classes(:one).to_param
    end

    assert_redirected_to ticket_classes_path
  end
end
