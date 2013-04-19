require_relative '../../spec_helper'

describe Admin::MembershipsController do
  fixtures :all
  render_views

  it "index action should render index template" do
    get :index
    response.should render_template(:index)
  end

  it "show action should render show template" do
    get :show, :id => Membership.first
    response.should render_template(:show)
  end

  it "new action should render new template" do
    get :new
    response.should render_template(:new)
  end

  it "create action should render new template when model is invalid" do
    Membership.any_instance.stubs(:valid?).returns(false)
    post :create
    response.should render_template(:new)
  end

  it "create action should redirect when model is valid" do
    Membership.any_instance.stubs(:valid?).returns(true)
    post :create
    response.should redirect_to(admin_membership_url(assigns[:membership]))
  end

  it "edit action should render edit template" do
    get :edit, :id => Membership.first
    response.should render_template(:edit)
  end

  it "update action should render edit template when model is invalid" do
    Membership.any_instance.stubs(:valid?).returns(false)
    put :update, :id => Membership.first
    response.should render_template(:edit)
  end

  it "update action should redirect when model is valid" do
    Membership.any_instance.stubs(:valid?).returns(true)
    put :update, :id => Membership.first
    response.should redirect_to(admin_membership_url(assigns[:membership]))
  end

  it "destroy action should destroy model and redirect to index action" do
    membership = Membership.first
    delete :destroy, :id => membership
    response.should redirect_to(admin_memberships_url)
    Membership.exists?(membership.id).should be_false
  end
end
