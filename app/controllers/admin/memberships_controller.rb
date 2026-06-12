class Admin::MembershipsController < ApplicationController
  def index
    @memberships = Membership.all
  end

  def show
    @membership = Membership.find(params[:id])
  end

  def new
    @membership = Membership.new
  end

  def create
    @membership = Membership.new(membership_params)
    if @membership.save
      redirect_to [:admin, @membership], :notice => "Successfully created membership."
    else
      render :action => 'new'
    end
  end

  def edit
    @membership = Membership.find(params[:id])
  end

  def update
    @membership = Membership.find(params[:id])
    if @membership.update(membership_params)
      redirect_to [:admin, @membership], :notice => "Successfully updated membership."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @membership = Membership.find(params[:id])
    @membership.destroy
    redirect_to admin_memberships_url, :notice => "Successfully destroyed membership."
  end

  private

  def membership_params
    params.require(:membership).permit(:membership_offer_id, :member_since, :member_code, :status, :preferred_seating)
  end
end
