class Admin::FlexPassOfferOrdersController < Admin::ApplicationController
  def new
    @order = Order.new
    @order.address = Address.new
    @flex_pass_offer = FlexPassOffer.find(params[:flex_pass_offer_id])
    @order.cash_payments.build
    @order.credit_card_payments.build
  end
  
  def create
    order_params = params[:order]
    @order = Order.new(order_params)
    @flex_pass_offer = FlexPassOffer.find(params[:flex_pass_offer_id])
    flex_pass_line_item = @order.flex_pass_line_items.build()
    flex_pass_line_item.flex_pass_offer=@flex_pass_offer
    flex_pass_line_item.flex_pass=@flex_pass_offer.flex_passes.build
    
   
    begin
      @payment = @order.process!
    
      flash[:notice] = 'Order was successfully created.'
      redirect_to(admin_flex_pass_offer_order_path(@flex_pass_offer.id, @order.id))
    rescue StandardError => e
      @order.status = nil
        case e
        when InvalidCreditCard
          flash.now[:notice] = "The credit card you entered was invalid. Reason: #{e.message}"
        when CannotProcessPayment
          flash.now[:notice] = "There was an error while processing your credit card. #{e.message}"
        when ActiveRecord::RecordInvalid
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        else
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        end
        render :new
    end
  end
  
  def show
    @order = Order.find(params[:id])
    @flex_pass_offer = FlexPassOffer.find(params[:flex_pass_offer_id])
    
  end
  
end

