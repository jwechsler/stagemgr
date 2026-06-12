class SalesByPerformanceReport < Report
  attr_accessor :productions, :breakdown_by_ticket_class, :restrict_to_performances

  def initialize(production_list, breakdown_by_ticket_class = true, restrict_to_performance_ids = nil,
                 reporting_user_id = nil)
    @productions = []
    production_list.each do |prod|
      prod = Production.find(prod) unless prod.is_a?(Production)
      @productions << prod
    end
    @breakdown_by_ticket_class = @productions.size.eql?(1) ? breakdown_by_ticket_class : false
    @restrict_to_performances = restrict_to_performance_ids.nil? ? nil : Performance.where(id: restrict_to_performance_ids)

    super([], reporting_user_id)
  end

  def create
    # Canonical revenue vocabulary (see RevenueCalculator):
    #   :revenue_collected => total of all payments  (RevenueCalculator#collected)
    #   :reportable        => sales-reportable subset (RevenueCalculator#reportable)
    # The :revenue_collected column was historically keyed/labeled "Gross"; it is
    # renamed here to "Revenue Collected" per the product owner. Column order is
    # unchanged.
    report = []
    total_tickets = {}
    total_tickets[:revenue_collected] = Money.new(0)
    total_tickets[:reportable] = Money.new(0)
    total_tickets[:facility] = Money.new(0)
    total_tickets[:processing] = Money.new(0)
    total_tickets[:paid] = 0
    total_tickets[:holds] = 0
    total_tickets[:display_class] = :report_summary_row

    productions.sort! { |p1, p2| p1.name <=> p2.name }
    productions.each do |production|
      subtotal = {}
      ticket_classes = production.ticket_classes.sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
      ticket_classes.each { |tc| total_tickets[tc.class_code] = 0 }
      subtotal[:revenue_collected] = Money.new(0)
      subtotal[:reportable] = Money.new(0)
      subtotal[:facility] = Money.new(0)
      subtotal[:processing] = Money.new(0)
      subtotal[:paid] = 0
      subtotal[:holds] = 0
      subtotal[:display_class] = :report_summary_row
      subtotal[:performance_code] = production.production_code
      # header row
      use_performances = if restrict_to_performances.nil?
                           production.performances
                         else
                           restrict_to_performances.select do |p|
                             p.production.id == production.id
                           end
                         end
      use_performances.sort do |x, y|
        if x.performance_date == y.performance_date
          x.performance_time <=> y.performance_time
        else
          x.performance_date <=> y.performance_date
        end
      end.each do |perf|
        settled_orders = perf.orders.select { |o| o.settled? }
        held_orders = perf.orders.select { |o| o.held? }
        paid_tickets = settled_orders.sum { |o| o.number_of_tickets }
        held_tickets = held_orders.sum { |o| o.number_of_tickets }
        max_ticket_price = perf.ticket_class_allocations.select do |tca|
          tca.available? && !tca.ticket_class.nil?
        end.max_by { |tca| tca.ticket_class.ticket_price }.ticket_class.ticket_price
        revenue = RevenueCalculator.for(settled_orders)
        revenue_collected = revenue.collected.to_money
        reportable = revenue.reportable.to_money
        ticketing_fee = revenue.ticketing_fees.to_money
        processing_fee = revenue.processing_fees.to_money
        subtotal[:revenue_collected] += revenue_collected
        subtotal[:reportable] += reportable
        subtotal[:facility] += ticketing_fee
        subtotal[:processing] += processing_fee
        subtotal[:paid] += paid_tickets
        subtotal[:holds] += held_tickets
        row = { performance_code: perf.performance_code,
                performance_date: perf.performance_date,
                performance_time: perf.performance_time,
                display_class: :report_detail_row,
                max_ticket: max_ticket_price.to_money }
        if breakdown_by_ticket_class
          ticket_classes.each do |tc|
            class_qty = settled_orders.sum { |o| o.ticket_quantity_by_class(tc.class_code) }
            total_tickets[tc.class_code] += class_qty
            row[tc.class_code] = class_qty
          end

        end

        row[:paid] = paid_tickets
        row[:holds] = held_tickets
        row[:revenue_collected] = revenue_collected
        row[:reportable] = reportable
        row[:facility] = ticketing_fee
        row[:processing] = processing_fee
        row[:net] = reportable - (ticketing_fee + processing_fee)
        report << row
      end
      subtotal[:net] = subtotal[:reportable] - (subtotal[:facility] + subtotal[:processing])

      report << subtotal
      total_tickets[:revenue_collected] += subtotal[:revenue_collected]
      total_tickets[:reportable] += subtotal[:reportable]
      total_tickets[:facility] += subtotal[:facility]
      total_tickets[:processing] += subtotal[:processing]
      total_tickets[:paid] += subtotal[:paid]
      total_tickets[:holds] += subtotal[:holds]
    end

    total_tickets[:net] = total_tickets[:reportable] - (total_tickets[:facility] + total_tickets[:processing])
    total_tickets[:performance_code] = 'TOTAL'
    report << total_tickets if productions.size > 1

    # Build headers, filtering out ticket classes with zero sales
    @headers = %i[performance_code performance_date performance_time]
    if breakdown_by_ticket_class
      productions.first.ticket_classes
                 .sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
                 .each { |tc| @headers << tc.class_code if (total_tickets[tc.class_code] || 0) > 0 }
    end
    @headers += %i[paid holds max_ticket revenue_collected reportable facility processing net]

    [headers, report]
  end
end
