class Admin::ApplicationController < ApplicationController

  protected

  def permission_denied
    flash[:error] = "Sorry, you are not allowed to access that page."
    redirect_to root_url
  end


  def find_context
    @context, @rest_path =
    case
    when (self.class == Admin::TheatersController) && params[:id]
      [Theater.find(params[:id])].map{|m| [m , [:admin, m]]}.first
    when (self.class == Admin::ProductionsController) && params[:id]
      [Production.find(params[:id])].map{|m| [m , [:admin, m.theater, m]]}.first
    when params[:ticket_class_id]
      [TicketClass.find(params[:ticket_class_id])].map{|m| [m , [:admin, m.theater, m.production, m]]}.first
    when params[:performance_id]
      [Performance.find(params[:performance_id])].map{|m| [m , [:admin, m.theater, m.production, m]]}.first
    when params[:production_id]
      [Production.find(params[:production_id])].map{|m| [m , [:admin, m.theater, m]]}.first
    when params[:theater_id]
      [Theater.find(params[:theater_id])].map{|m| [m , [:admin, m]]}.first
    else
      nil
    end
    raise ActiveRecord::RecordNotFound if @context.nil?
  end


end
