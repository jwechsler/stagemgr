# Staff report: for a given performance date, what shared equipment (a
# ResourcedTicketClass's device pool -- captioning tablets, AD receivers, ...)
# must be pulled/prepped, and for whom.
#
# Grouped by resourced ticket class; within each group, one row per order with
# that order's net device count for the class (refund TLIs are negative
# ticket_count rows, so summing an order's rows nets them out -- an order that
# nets to zero or less is dropped). Rows are sorted by performance_code, then
# patron last/first name, so staff can read the sheet performance by
# performance. Pattern: HouseManagementReport.
class ResourcePullReport < Report
  attr_accessor :for_date

  def initialize(for_date, reporting_user_id = nil)
    super(reporting_user_id)
    self.for_date = for_date
  end

  def line_items
    TicketLineItem
      .joins(:ticket_class, order: { performance: :production })
      .where.not(ticket_classes: { resourced_ticket_class_id: nil })
      .where(performances: { performance_date: for_date })
      .where(orders: { status: Order::RESOURCE_OCCUPYING_STATUSES })
      .includes(:ticket_class, order: [:address, { performance: :production }])
  end

  # [headers, report] where report is one hash per resourced ticket class:
  #   { resource_code:, resource_name:, rows: [...], performance_subtotals: {},
  #     total: }
  # sorted by resource class_code. Each row: performance_code,
  # performance_time, production_name, patron_name, device_count.
  def create
    headers = %i[resource_code resource_name performance_code performance_time
                 production_name patron_name device_count]

    report = resource_groups.filter_map do |resource, rows|
      next if rows.empty?

      {
        resource_code: resource.class_code,
        resource_name: resource.class_name,
        rows: rows,
        performance_subtotals: subtotals_by_performance(rows),
        total: rows.sum { |row| row[:device_count] }
      }
    end

    [headers, report]
  end

  private

  def resource_groups
    line_items.group_by { |tli| tli.ticket_class.resourced_ticket_class }
              .transform_values { |items| net_rows_for(items) }
              .sort_by { |resource, _rows| resource.class_code }
  end

  # One row per order: net device count across that order's line items for
  # this resourced class (a refund is a second, negative-count row on the same
  # order). Orders that net to zero or less pulled no equipment and are
  # dropped.
  def net_rows_for(items)
    items.group_by(&:order)
         .filter_map { |order, order_items| net_row_for(order, order_items) }
         .sort_by { |row| [row[:performance_code], row[:last_name].to_s, row[:first_name].to_s] }
  end

  def net_row_for(order, order_items)
    count = order_items.sum(&:ticket_count)
    return nil if count <= 0

    performance = order.performance
    address = order.address
    {
      performance_code: performance.performance_code,
      performance_time: performance.performance_time.to_formatted_s(:standard_time),
      production_name: performance.production.name,
      patron_name: address.full_name,
      last_name: address.last_name,
      first_name: address.first_name,
      device_count: count
    }
  end

  def subtotals_by_performance(rows)
    rows.group_by { |row| row[:performance_code] }
        .transform_values { |perf_rows| perf_rows.sum { |row| row[:device_count] } }
  end
end
