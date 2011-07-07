require 'test_helper'

class Admin::MembershipOffersControllerTest < ActionController::TestCase
  def test_index
    get :index
    assert_template 'index'
  end

  def test_show
    get :show, :id => MembershipOffer.first
    assert_template 'show'
  end

  def test_new
    get :new
    assert_template 'new'
  end

  def test_create_invalid
    MembershipOffer.any_instance.stubs(:valid?).returns(false)
    post :create
    assert_template 'new'
  end

  def test_create_valid
    MembershipOffer.any_instance.stubs(:valid?).returns(true)
    post :create
    assert_redirected_to admin_membership_offer_url(assigns(:membership_offer))
  end

  def test_edit
    get :edit, :id => MembershipOffer.first
    assert_template 'edit'
  end

  def test_update_invalid
    MembershipOffer.any_instance.stubs(:valid?).returns(false)
    put :update, :id => MembershipOffer.first
    assert_template 'edit'
  end

  def test_update_valid
    MembershipOffer.any_instance.stubs(:valid?).returns(true)
    put :update, :id => MembershipOffer.first
    assert_redirected_to admin_membership_offer_url(assigns(:membership_offer))
  end

  def test_destroy
    membership_offer = MembershipOffer.first
    delete :destroy, :id => membership_offer
    assert_redirected_to admin_membership_offers_url
    assert !MembershipOffer.exists?(membership_offer.id)
  end
end
