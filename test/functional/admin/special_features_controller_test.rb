require 'test_helper'

class Admin::SpecialFeaturesControllerTest < ActionController::TestCase
  def test_index
    get :index
    assert_template 'index'
  end

  def test_show
    get :show, :id => SpecialFeature.first
    assert_template 'show'
  end

  def test_new
    get :new
    assert_template 'new'
  end

  def test_create_invalid
    SpecialFeature.any_instance.stubs(:valid?).returns(false)
    post :create
    assert_template 'new'
  end

  def test_create_valid
    SpecialFeature.any_instance.stubs(:valid?).returns(true)
    post :create
    assert_redirected_to admin_special_feature_url(assigns(:special_feature))
  end

  def test_edit
    get :edit, :id => SpecialFeature.first
    assert_template 'edit'
  end

  def test_update_invalid
    SpecialFeature.any_instance.stubs(:valid?).returns(false)
    put :update, :id => SpecialFeature.first
    assert_template 'edit'
  end

  def test_update_valid
    SpecialFeature.any_instance.stubs(:valid?).returns(true)
    put :update, :id => SpecialFeature.first
    assert_redirected_to admin_special_feature_url(assigns(:special_feature))
  end

  def test_destroy
    special_feature = SpecialFeature.first
    delete :destroy, :id => special_feature
    assert_redirected_to admin_special_features_url
    assert !SpecialFeature.exists?(special_feature.id)
  end
end
