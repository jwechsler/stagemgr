class Admin::ApplicationController < ApplicationController

  rescue_from CanCan::AccessDenied do |exception|
      respond_to do |format|
        format.json { head :forbidden, content_type: 'text/html' }
        format.html { redirect_to main_app.root_url, notice: exception.message }
        format.js   { head :forbidden, content_type: 'text/html' }
      end
    end

  before_action :prepare_exception_notifier

  protected

  def permission_denied
    flash[:error] = "Sorry, you are not allowed to access that page."
    redirect_to root_url
  end

  def current_ability
    if self.current_user.nil?
      raise CanCan::AccessDenied
    end
    self.current_user.ability
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

  private
  def prepare_exception_notifier
    request.env["exception_notifier.exception_data"] = {
      user_id: current_user.id,
      user_email: current_user.email
    }
  end


end
