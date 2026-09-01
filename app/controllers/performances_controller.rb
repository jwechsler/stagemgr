class PerformancesController < ApplicationController
  helper PerformancesHelper
  layout Rails.configuration.x.server_config['ext_site_wrapper']

  before_action :find_production, except: %i[ticket_classes]

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
      @footnotes = special_feature_footnotes(@performances)

      @list_performances = @production.performances.includes(
        :house_count, :ticket_class_allocations, :special_features, :production
      ).where(
        'performances.status in (?) and performances.performance_date >= ?',
        Performance.visible_statuses, Date.today
      ).order(performance_date: :asc, performance_time: :asc)

      @list_footnotes = special_feature_footnotes(@list_performances)

      render :index, layout: Rails.configuration.x.server_config['ext_site_wrapper']
    end
  end

  def ticket_classes
    @performance = Performance.find(params[:id])
    # Backend (non-web-visible) classes are included only when the caller asks
    # for them AND has the ability — the admin box-office page sends
    # include_backend=1 (see _seating_config). The public order flow never
    # sends the param, so signed-in staff browsing the public page still get
    # the customer-facing list. Spoofing the param without the ability is inert.
    include_backend = params[:include_backend].present? &&
                      current_user&.can?(:view_backend_classes, TicketClassAllocation)
    if @performance.inactive? || @performance.production.inactive?
      visible_to_public = []
    else
      visible_to_public = @performance.ticket_class_allocations.select do |tca|
        tca.available? && (tca.ticket_class.web_visible? || include_backend) &&
          !tca.ticket_class.software_managed? && tca.ticket_class.resource_available?(@performance)
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
        purchase_page_annotation: tca.ticket_class.purchase_page_annotation,
        zone_id: tca.ticket_class.zone_id,
        holds_seats: tca.ticket_class.holds_seats?,
        remaining: tca.ticket_class.resourced? ? tca.ticket_class.number_left(@performance) : nil
      }
    }
  end

  private

  # Footnote keys, in order of first appearance, for the special features shown
  # against a set of performances. Custom copy is keyed by the copy itself (see
  # Performance#custom_footnote_key), so two performances carrying identical
  # "Custom Special Feature" text share one footnote rather than duplicating it.
  def special_feature_footnotes(performances)
    performances.flat_map do |p|
      p.special_features.map(&:short_name) << p.custom_footnote_key
    end.compact.uniq
  end

  def find_production
    @production = Production.sellable_to_public.find_by(id: params[:production_id])
    return if @production

    flash[:notice] = 'The production you are looking for is not currently on sale.'
    redirect_to box_office_productions_path
  end
end
