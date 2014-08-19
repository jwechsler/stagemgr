class Admin::MembershipOffersController < ApplicationController
  filter_resource_access

  def index
    @membership_offers = MembershipOffer.order(:status, :name).all
  end

  def show
    @membership_offer = MembershipOffer.find(params[:id])
  end

  def new
    @membership_offer = MembershipOffer.new
  end

  def create
    @membership_offer = MembershipOffer.new(params[:membership_offer])
    if @membership_offer.save
      redirect_to [:admin, @membership_offer], :notice => "Successfully created membership offer."
    else
      render :action => 'new'
    end
  end

  def edit
    @membership_offer = MembershipOffer.find(params[:id])
  end

  def update
    @membership_offer = MembershipOffer.find(params[:id])
    if @membership_offer.update_attributes(params[:membership_offer])
      redirect_to [:admin, @membership_offer], :notice  => "Successfully updated membership offer."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @membership_offer = MembershipOffer.find(params[:id])
    @membership_offer.destroy
    redirect_to admin_membership_offers_url, :notice => "Successfully destroyed membership offer."
  end
end
