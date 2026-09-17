class Admin::MembershipsController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html
      format.json do
        params.permit!
        render json: MembershipDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  def show; end

  def new
    @membership.address_id = params[:address_id] if params[:address_id].present?
    @membership.membership_offer_id = params[:membership_offer_id] if params[:membership_offer_id].present?
    @membership.status ||= Membership::ACTIVE
    @membership.member_since ||= Date.current
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

  # Renders the printable member ID card and streams it as a download. The
  # button only appears when the offer has a background, but the redirect
  # covers a stale page or a hand-typed URL.
  def id_card
    unless @membership.membership_offer.card_available?
      redirect_to [:admin, @membership], alert: 'This offer has no ID card background uploaded yet.'
      return
    end

    card = MembershipCards::Card.new(@membership)
    send_data card.png, type: 'image/png', filename: card.filename, disposition: 'attachment'
  rescue MembershipCards::RenderError => e
    Rails.logger.error("[MembershipCards] membership #{@membership.id}: #{e.message}")
    redirect_to [:admin, @membership], alert: "The ID card could not be rendered: #{e.message}"
  end

  private

  def membership_params
    params.require(:membership).permit(:membership_offer_id, :member_since, :member_code, :status,
                                       :preferred_seating, :address_id)
  end
end
