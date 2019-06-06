class PerformancesController < ApplicationController
  helper PerformancesHelper
  layout 'ext_site_wrapper'

  append_before_filter :find_production, :except=>[:by_date]

  def index
    if !@production.nil?
      begin
        valid_date = params[:start_date].nil? ? nil : Date.parse(params[:start_date])
      rescue ArgumentError
        valid_date = nil
      end

      @start_date = valid_date.nil? ? (@production.first_preview_at.nil? ? Date.today.beginning_of_month : ((@production.first_preview_at.beginning_of_month < Date.today.beginning_of_month) ? Date.today.beginning_of_month : @production.first_preview_at.beginning_of_month)) : valid_date
      @end_date = @start_date.end_of_month;
      @performances = @production.performances.includes(
        :ticket_class_allocations, :orders, :special_features, :production,
        {:orders=>:ticket_line_items}
      ).where(
        'performances.status in (?) and performances.performance_date >= ? and performances.performance_date <= ?',
        Performance.visible_statuses, @start_date, @end_date
      ).order(:performance_date=>:asc, :performance_time=>:asc)
      @footnotes = Array.new
      @performances.each {|p|
        unless p.special_features.empty?

          @footnotes += p.special_features.map {|f| f.short_name}

        end
        @footnotes << "_custom#{p.id}" unless p.special_feature_display_markdown.blank?
      }
      @footnotes = @footnotes.uniq
      render :index, :layout=>'ext_site_wrapper'
    else
      super
    end

  end

  def by_date
    @footnotes = Array.new
    @start_date = params[:start_date].nil? ? Date.today.beginning_of_week : Date.parse(params[:start_date])
    @end_date = params[:end_date].nil? ? Date.today.beginning_of_week + 1.week - 1 : Date.parse(params[:end_date])
    @performances = Performance.where('performances.performance_date >= ? and performances.performance_date <= ?',@start_date,@end_date).order(:performance_date, :performance_time)
    @performances.select!{|p| p.production.visible? && p.production.sellable_to_public?}
    @performances.each {|p|
      unless p.special_features.empty?
        @footnotes += p.special_features.map {|f| f.short_name}
        @footnotes << "_custom#{p.id}"
      end
    }
    render :by_date, :layout=>'ext_site_wrapper'
  end


  private

  def find_production
    @production = Production.sellable_to_public.find(params[:production_id])
  end
end
