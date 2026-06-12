class PerformancesController < ApplicationController
  helper PerformancesHelper
  layout $SERVER_CONFIG['ext_site_wrapper']

  before_action :find_production, except: %i[by_date ticket_classes]

  def index
    if @production.nil?
      super
    else
      begin
        valid_date = params[:start_date].nil? ? nil : Date.parse(params[:start_date])
      rescue ArgumentError
        valid_date = nil
      end

      @start_date = if valid_date.nil?
                      if @production.first_preview_at.nil?
                        Date.today.beginning_of_month
                      else
                        (@production.first_preview_at.beginning_of_month < Date.today.beginning_of_month ? Date.today.beginning_of_month : @production.first_preview_at.beginning_of_month)
                      end
                    else
                      valid_date
                    end
      @end_date = @start_date.end_of_month
      @performances = @production.performances.includes(
        :house_count, :ticket_class_allocations, :special_features, :production
      ).where(
        'performances.status in (?) and performances.performance_date >= ? and performances.performance_date <= ?',
        Performance.visible_statuses, @start_date, @end_date
      ).order(performance_date: :asc, performance_time: :asc)
      @footnotes = []
      @performances.each do |p|
        @footnotes += p.special_features.map { |f| f.short_name } unless p.special_features.empty?
        @footnotes << "_custom#{p.id}" if p.special_feature_display_markdown.present?
      end
      @footnotes = @footnotes.uniq

      @list_performances = @production.performances.includes(
        :house_count, :ticket_class_allocations, :special_features, :production
      ).where(
        'performances.status in (?) and performances.performance_date >= ?',
        Performance.visible_statuses, Date.today
      ).order(performance_date: :asc, performance_time: :asc)

      @list_footnotes = []
      @list_performances.each do |p|
        @list_footnotes += p.special_features.map(&:short_name) unless p.special_features.empty?
        @list_footnotes << "_custom#{p.id}" if p.special_feature_display_markdown.present?
      end
      @list_footnotes.uniq!

      render :index, layout: $SERVER_CONFIG['ext_site_wrapper']
    end
  end

  def by_date
    @footnotes = []
    @start_date = parse_date_param(:start_date, default: Date.today.beginning_of_week)
    @end_date = parse_date_param(:end_date, default: Date.today.beginning_of_week + 1.week - 1)
    @performances = Performance.where('performances.performance_date >= ? and performances.performance_date <= ?', @start_date, @end_date).order(
      :performance_date, :performance_time
    )
    @performances.select! { |p| p.production.visible? && p.production.sellable_to_public? }
    @performances.each do |p|
      unless p.special_features.empty?
        @footnotes += p.special_features.map { |f| f.short_name }
        @footnotes << "_custom#{p.id}"
      end
    end
    render :by_date, layout: $SERVER_CONFIG['ext_site_wrapper']
  end

  def ticket_classes
    @performance = Performance.find(params[:id])
    if @performance.inactive? || @performance.production.inactive?
      visible_to_public = []
    else
      visible_to_public = @performance.ticket_class_allocations.select do |tca|
        tca.available? && (tca.ticket_class.web_visible? || current_user&.can?(:view_backend_classes,
                                                                               TicketClassAllocation)) && !tca.ticket_class.software_managed?
      end.sort do |a, b|
        [(b.ticket_class.web_visible? ? 1 : 0), b.ticket_class.ticket_price,
         a.ticket_class.class_name] <=> [(a.ticket_class.web_visible? ? 1 : 0), a.ticket_class.ticket_price,
                                         b.ticket_class.class_name]
      end
    end
    render json: visible_to_public.map { |tca|
      {
        id: tca.ticket_class.id,
        class_name: tca.ticket_class.class_name,
        web_visible: tca.ticket_class.web_visible?,
        ticket_price: tca.ticket_class.software_managed? || tca.ticket_class.hide_pricing? ? 'n/a' : view_context.number_to_currency(tca.ticket_class.ticket_price),
        raw_ticket_price: tca.ticket_class.ticket_price,
        ticket_type: tca.ticket_class.ticket_type,
        purchase_page_annotation: tca.ticket_class.purchase_page_annotation
      }
    }
  end

  private

  def find_production
    @production = Production.sellable_to_public.find_by(id: params[:production_id])
    return if @production

    flash[:notice] = 'The production you are looking for is not currently on sale.'
    redirect_to box_office_productions_path
  end
end
