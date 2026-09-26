class Admin::ResourcedTicketClassesController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.haml
      format.json do
        params.permit!
        render json: ResourcedTicketClassDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  # Show also gathers the operational warnings the admin needs to resolve:
  # productions missing running_time (occupancy math falls back to the
  # server.yml default), productions in scope that never got a shadow row
  # (usually a class_code collision the sync job logged), and shadow rows that
  # already have sales (relevant if the resource is about to be edited/deleted).
  def show
    @syncing = @resourced_ticket_class.syncing?
    @shadow_classes_with_sales = @resourced_ticket_class.shadow_classes_with_sales
    @productions_missing_running_time =
      Production.where(venue_id: @resourced_ticket_class.venue_ids, running_time: nil)
    # Meaningless mid-sync: rows the job has not created yet are not conflicts.
    @productions_missing_shadow_class =
      if @syncing
        Production.none
      else
        SyncResourcedTicketClassJob.productions_in_scope(@resourced_ticket_class)
                                   .where.not(id: @resourced_ticket_class.ticket_classes.select(:production_id))
      end
  end

  # Polled by the show page's syncing banner (mirrors
  # Admin::ProductionsController#allocation_sync_status).
  def sync_status
    render json: { syncing: @resourced_ticket_class.syncing? }
  end

  def new; end

  def edit; end

  def create
    if @resourced_ticket_class.save
      redirect_to [:admin, @resourced_ticket_class], notice: 'Successfully created resourced ticket class.'
    else
      render action: 'new'
    end
  end

  def update
    if @resourced_ticket_class.update(resourced_ticket_class_params)
      redirect_to [:admin, @resourced_ticket_class],
                  success: "Successfully updated resourced ticket class #{@resourced_ticket_class.class_code}."
    else
      render action: 'edit'
    end
  end

  # The model refuses to destroy a resource with sold shadow classes: it
  # decommissions them instead (withdraws from sale, keeps history) and adds an
  # error rather than deleting. Surface that explanation instead of a generic
  # failure message.
  def destroy
    if @resourced_ticket_class.destroy
      redirect_to admin_resourced_ticket_classes_url, notice: 'Successfully destroyed resourced ticket class.'
    else
      redirect_to admin_resourced_ticket_classes_url,
                  flash: { error: @resourced_ticket_class.errors.full_messages.to_sentence }
    end
  end

  private

  # Same set as Admin::TicketClassesController#ticket_class_params minus
  # :production_id, plus the pool attributes.
  def resourced_ticket_class_params
    params.require(:resourced_ticket_class).permit(:class_code, :class_name, :ticket_type,
                                                   :ticket_price, :ticketing_fee, :web_visible, :software_managed,
                                                   :holds_seats, :assigns_seats, :show_in_pricing_range,
                                                   :minutes_before_show, :suppress_receipt, :admission, :hide_pricing,
                                                   :purchase_page_annotation, :purchase_email_annotation,
                                                   :exchangeable, :royalty_amount, :zone_id, :complimentary,
                                                   :quantity, :changeover_minutes, venue_ids: [])
  end
end
