class Admin::ApplicationController < ApplicationController
  rescue_from CanCan::AccessDenied do |_exception|
    if current_user.nil?
      # User session has expired, redirect to the login page
      flash[:alert] = 'Your session has expired. Please log in again.'
      redirect_to login_path
    else
      # User is logged in but does not have permission
      flash[:alert] = 'You are not authorized to access this page.'
      redirect_to root_path
    end
  end
  before_action :prepare_exception_notifier

  protected

  def permission_denied
    flash[:error] = 'Sorry, you are not allowed to access that page.'
    redirect_to root_url
  end

  def current_ability
    raise CanCan::AccessDenied if current_user.nil?

    current_user.ability
  end

  def find_context
    @context, @rest_path =
      if (self.class == Admin::TheatersController) && params[:id]
        [Theater.find(params[:id])].map { |m| [m, [:admin, m]] }.first
      elsif (self.class == Admin::ProductionsController) && params[:id]
        [Production.find(params[:id])].map { |m| [m, [:admin, m.theater, m]] }.first
      elsif params[:ticket_class_id]
        [TicketClass.find(params[:ticket_class_id])].map { |m| [m, [:admin, m.theater, m.production, m]] }.first
      elsif params[:performance_id]
        [Performance.find(params[:performance_id])].map { |m| [m, [:admin, m.theater, m.production, m]] }.first
      elsif params[:production_id]
        [Production.find(params[:production_id])].map { |m| [m, [:admin, m.theater, m]] }.first
      elsif params[:theater_id]
        [Theater.find(params[:theater_id])].map { |m| [m, [:admin, m]] }.first
      end
    raise ActiveRecord::RecordNotFound if @context.nil?
  end

  private

  def prepare_exception_notifier
    request.env['exception_notifier.exception_data'] = {
      user_id: current_user&.id,
      user_email: current_user&.email
    }
  end
end
