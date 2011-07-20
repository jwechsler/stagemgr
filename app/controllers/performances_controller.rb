class PerformancesController < ApplicationController
  append_before_filter :find_production
  
  def index
    @start_date = params[:start_date].nil? ? (@production.first_preview_at.nil? ? Date.today.beginning_of_month : ((@production.first_preview_at.beginning_of_month < Date.today.beginning_of_month) ? Date.today.beginning_of_month : @production.first_preview_at.beginning_of_month)) : Date.parse(params[:start_date])
    @end_date = @start_date.end_of_month;
    @performances = @production.performances.find(:all, :conditions=>['performances.status != \'Inactive\' and performances.performance_date >= ? and performances.performance_date <= ?',@start_date,@end_date], :order=>'performances.performance_date, performances.performance_time asc')
    render :index, :layout=>'ext_site_wrapper'
  end

  private
  
  def find_production
    @production = Production.find(params[:production_id])
  end  
end
