class PerformancesController < ApplicationController
  append_before_filter :find_production
  
  def index
    @start_date = params[:start_date].nil? ? Date.today.beginning_of_month : Date.parse(params[:start_date])
    @end_date = params[:end_date].nil? ? Date.today.end_of_month : Date.parse(params[:end_date])
    @performances = @production.performances.find(:all, :conditions=>['performances.performance_date >= ? and performances.performance_date <= ?',@start_date,@end_date], :order=>'performances.performance_date, performances.performance_time asc')
    render :index, :layout=>false
  end
  
  private
  
  def find_production
    @production = Production.find(params[:production_id])
  end  
end
