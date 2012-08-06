require 'test_helper'

class Admin::DefaultTicketClassesControllerTest < ActionController::TestCase

  def setup
    @sample_record = FactoryGirl.create(:default_ticket_class)
    @sample_record.save!
  end

  def teardown
    @sample_record.destroy
  end
  def test_index
    get :index
    assert_template 'index'
  end

  def test_show
    get :show, :id => DefaultTicketClass.first
    assert_template 'show'
  end

  def test_new
    get :new
    assert_template 'new'
  end

  def test_create_invalid
    DefaultTicketClass.any_instance.stubs(:valid?).returns(false)
    post :create
    assert_template 'new'
  end

  def test_create_valid
    DefaultTicketClass.any_instance.stubs(:valid?).returns(true)
    post :create
    assert_redirected_to admin_default_ticket_class_url(assigns(:default_ticket_class))
  end

  def test_edit
    get :edit, :id => DefaultTicketClass.first
    assert_template 'edit'
  end

  def test_update_invalid
    DefaultTicketClass.any_instance.stubs(:valid?).returns(false)
    put :update, :id => DefaultTicketClass.first
    assert_template 'edit'
  end

  def test_update_valid
    DefaultTicketClass.any_instance.stubs(:valid?).returns(true)
    put :update, :id => DefaultTicketClass.first
    assert_redirected_to admin_default_ticket_class_url(assigns(:default_ticket_class))
  end

  def test_destroy
    default_ticket_class = DefaultTicketClass.first
    delete :destroy, :id => default_ticket_class
    assert_redirected_to admin_default_ticket_classes_url
    assert !DefaultTicketClass.exists?(default_ticket_class.id)
  end
end
