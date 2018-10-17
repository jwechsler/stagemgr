class Admin::PaymentTypesController < Admin::ApplicationController

  authorize_resource

  def index
    @payment_types = PaymentType.all
  end

  def edit
    @payment_type = PaymentType.find(params[:id])
  end

  def new_external_payment
    @payment_type = ExternalPaymentType.new
    respond_to do |format|
      format.html { render :action=>"new"}
      format.xml
    end
  end

  def update
    @payment_type = PaymentType.find(params[:id])
    @payment_type.update_attributes(payment_type_params)
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

  def create_external_payment
    @payment_type = ExternalPaymentType.create(payment_type_params)
    respond_to do |format|
      if @payment_type.save
        flash[:notice] =  raw "<i>#{@payment_type.display_name}</i> was successfully created."
        format.html { redirect_to(admin_payment_types_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @payment_type.errors, :status => :unprocessable_entity }
      end
    end

  end

  def destroy
    @payment_type.destroy
    if @payment_type.destroyed?
      flash[:notice] = raw "<i>#{@payment_type.display_name} deleted"
    else
      @payment_type.errors.full_messages.each { |m|
        flash[:error] = m
      }
    end
    redirect_to :action=>'index'
  end

  private
  def payment_type_params
    params.require(:payment_type).permit(:display_name, :allow_for_public, :allow_for_box_office, :report_as_sales_income,
      :restrict_to_ticket_classes, order_task_suppressions_attributes: [:task_type,
        :method_name])
  end

end
