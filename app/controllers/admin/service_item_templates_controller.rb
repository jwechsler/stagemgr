class Admin::ServiceItemTemplatesController < Admin::ApplicationController

  load_and_authorize_resource
   def index
    respond_to do |format|
      format.html
      format.json {
        params.permit!
        render json: ServiceItemTemplateDatatable.new(params, view_context: view_context, current_user: current_user )
      }
    end
  end

  def new
  end

  def create
    respond_to do |format|
      if @service_item_template.save
        flash[:notice] =  raw "<i>#{@service_item_template.name}</i> was successfully created."
        format.html { redirect_to(admin_service_item_templates_path) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def edit
  end

  def update
    @service_item_template.update_attributes(service_item_template_params)
    respond_to do |format|
      if @service_item_template.save
        flash[:notice] =  raw "<i>#{@service_item_template.name}</i> was updated."
        format.html { redirect_to(admin_service_item_templates_path) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def show
    respond_to do |format|
      format.html {
        render :action => "show"
      }
      format.json {
        render json: @service_item_template.to_json
      }
    end
  end


  private
  def service_item_template_params
    params.require(:service_item_template).permit(:name, :description, :internal_description, 
      :user_selectable, :amount, :facility_fee,:suppress_for_pass_payments)
  end

end
