class PerformancesController < ApplicationController
  layout 'ext_site_wrapper'

  append_before_filter :find_production, :except=>[:by_date]

  def index
    if !@production.nil?

      @start_date = params[:start_date].nil? ? (@production.first_preview_at.nil? ? Date.today.beginning_of_month : ((@production.first_preview_at.beginning_of_month < Date.today.beginning_of_month) ? Date.today.beginning_of_month : @production.first_preview_at.beginning_of_month)) : Date.parse(params[:start_date])
      @end_date = @start_date.end_of_month;
      @performances = @production.performances.find(:all, :include=>[:orders, :special_features, :production, {:orders=>:ticket_line_items}], :conditions=>['performances.status in (?) and performances.performance_date >= ? and performances.performance_date <= ?', Performance.visible_statuses, @start_date, @end_date], :order=>'performances.performance_date, performances.performance_time asc')
      @footnotes = Array.new
      @performances.each {|p| @footnotes += p.special_features.map {|f| f.short_name} }
      @footnotes = @footnotes.uniq
      render :index, :layout=>'ext_site_wrapper'
    else
      render :unavailable
    end

  end

  def by_date
    @footnotes = Array.new
    @start_date = params[:start_date].nil? ? Date.today.beginning_of_week : Date.parse(params[:start_date])
    @end_date = params[:end_date].nil? ? Date.today.beginning_of_week + 1.week - 1 : Date.parse(params[:end_date])
    @performances = Performance.where('performances.performance_date >= ? and performances.performance_date <= ?',@start_date,@end_date).order(:performance_date, :performance_time)
    @performances.each {|p| @footnotes += p.special_features.map {|f| f.short_name} }
    render :by_date, :layout=>'ext_site_wrapper'
  end


  private

  def find_production
    @production = Production.find(params[:production_id])
    @production = nil if @production.status == Production::INACTIVE
  end
end
