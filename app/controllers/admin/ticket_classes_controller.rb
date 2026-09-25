class Admin::TicketClassesController < Admin::ApplicationController
  load_and_authorize_resource

  prepend_before_action :find_production
  before_action :find_ticket_class, only: %i[edit update destroy]
  before_action :reject_resourced_shadow_class, only: %i[edit update destroy]

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json do
        params.permit!
        render json: TicketClassDatatable.new(params, view_context: view_context, current_user: current_user,
                                                      theater: @production.theater, production: @production)
      end
    end
  end

  def new
    @ticket_class.production = @production
  end

  def edit; end

  def create
    respond_to do |format|
      if @ticket_class.save
        flash[:notice] = 'TicketClass was successfully created.'
        format.html { redirect_to(admin_theater_production_ticket_classes_path(@theater, @production)) }
        format.xml  { render xml: @ticket_class, status: :created, location: @ticket_class }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @ticket_class.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @ticket_class.update(ticket_class_params)
        flash[:notice] = 'TicketClass was successfully updated.'
        format.html { redirect_to(admin_theater_production_ticket_classes_path(@theater, @production)) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @ticket_class.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    begin
      @ticket_class.destroy
    rescue Exception => e
      flash[:error] = e.message
    end
    respond_to do |format|
      format.html { redirect_to(admin_theater_production_ticket_classes_path(@theater, @production)) }
      format.xml  { head :ok }
    end
  end

  private

  def find_production
    @theater = Theater.find(params[:theater_id])
    @production = @theater.productions.find(params[:production_id])
  end

  def find_ticket_class
    @ticket_class = @production.ticket_classes.find(params[:id])
  end

  # Shadow rows are owned by their ResourcedTicketClass (see
  # TicketClass#prevent_manual_changes_to_resourced_class /
  # #prevent_manual_destroy_of_resourced_class, which back this up at the model
  # layer). Reject the request here instead of letting it fall through to a
  # validation error, so the admin gets a clear pointer to where the class is
  # actually managed.
  def reject_resourced_shadow_class
    return unless @ticket_class.resourced?

    flash[:error] = "'#{@ticket_class.class_code}' is managed globally by its resourced ticket class " \
                    "and cannot be edited from a production. Manage it at #{admin_resourced_ticket_classes_path}."
    redirect_to admin_theater_production_ticket_classes_path(@theater, @production)
  end

  def ticket_class_params
    params.require(:ticket_class).permit(:class_code, :class_name, :production_id, :ticket_type,
                                         :ticket_price, :ticketing_fee, :web_visible, :software_managed, :holds_seats, :assigns_seats,
                                         :show_in_pricing_range, :auto_attach, :minutes_before_show, :purchase_page_annotation,
                                         :purchase_email_annotation, :suppress_receipt, :admission, :hide_pricing, :exchangeable, :royalty_amount,
                                         :zone_id, :complimentary)
  end
end
