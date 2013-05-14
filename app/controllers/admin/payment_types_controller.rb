class Admin::PaymentTypesController < Admin::ApplicationController

  filter_resource_access

  def index
    @payment_types = PaymentType.order(:display_name).all
  end

  def edit
    @payment_type = PaymentType.find(params[:id])
  end

  def update
    @payment_type = PaymentType.find(params[:id])
    @payment_type.update_attributes(params[:payment_type])
    respond_to do |format|
      if (@payment_type.save)
        flash[:notice] =  raw "<i>#{@payment_type.type}</i> was successfully updated."
        format.html { redirect_to(admin_payment_types_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @payment_type.errors, :status => :unprocessable_entity }
      end
    end

  end

end
