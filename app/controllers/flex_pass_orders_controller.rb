class FlexPassOrdersController < ApplicationController
  layout 'ext_site_wrapper'
    include OrdersHelper

    append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
    append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

    respond_to :html, :xml, :json

    def new
    end

    def confirm
    end

    def show
    end

    def edit
    end

    def show;
    end

    def create
      @order = FlexPassOrder.new(params[:flex_pass_order])
      @order.ip_address = request.remote_ip
      process_order(@order, :edit_flex_pass_order_path) if validate_web_order(@order)
    end

    def update
      @order.attributes=params[:flex_pass_order]
      @order.ip_address = request.remote_ip
      validate_web_order(@order)
      process_order(@order, :edit_flex_pass_order_path)
    end

    def confirm
    end

    private
    def flex_pass_order_params
      params.require[:flex_pass_order].permit(*common_params)
    end

    def find_order
      @order = FlexPassOrder.find(params[:id])
    end

    def redirect_to_proper_action
      if @order.editable?
        if params[:action] != 'edit'
          redirect_to(edit_flex_pass_order_path(@order))
        end
      else
        if params[:action] != 'show'
          redirect_to(flex_pass_order_path(@order))
        end
      end
    end
end
