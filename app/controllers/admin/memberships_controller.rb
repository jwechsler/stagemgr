class Admin::MembershipsController < ApplicationController
  load_and_authorize_resource

  def index
    @memberships = @memberships.includes(:membership_offer, :address)
  end

  def show; end

  def new
    @membership.address_id = params[:address_id] if params[:address_id].present?
    @membership.membership_offer_id = params[:membership_offer_id] if params[:membership_offer_id].present?
    @membership.status ||= Membership::ACTIVE
    @membership.member_since ||= Date.today
  end

  def edit; end

  def create
    if @membership.save
      redirect_to [:admin, @membership], notice: 'Successfully created membership.'
    else
      render action: 'new'
    end
  end

  def update
    if @membership.update(membership_params)
      redirect_to [:admin, @membership], notice: 'Successfully updated membership.'
    else
      render action: 'edit'
    end
  end

  def destroy
    @membership.destroy
    redirect_to admin_memberships_url, notice: 'Successfully destroyed membership.'
  end

  private

  def membership_params
    params.require(:membership).permit(:membership_offer_id, :member_since, :member_code, :status,
                                       :preferred_seating, :address_id)
  end
end
