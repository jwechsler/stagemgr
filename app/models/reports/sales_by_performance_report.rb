class SalesByPerformanceReport < Report
  attr_accessor :productions
  attr_accessor :breakdown_by_ticket_class
  attr_accessor :restrict_to_performances

  def initialize(production_list, breakdown_by_ticket_class = true, restrict_to_performance_ids = nil,
                 reporting_user_id = nil)
    @productions = Array.new
    production_list.each do |prod|
      prod = Production.find(prod) unless prod.is_a?(Production)
      @productions << prod
    end
    @breakdown_by_ticket_class = @productions.size.eql?(1) ? breakdown_by_ticket_class : false
    @restrict_to_performances = restrict_to_performance_ids.nil? ? nil : Performance.where(id: restrict_to_performance_ids)

    super([], reporting_user_id)
  end

  def create
    report = Array.new
    total_tickets = Hash.new
    total_tickets[:gross] = Money.new(0)
    total_tickets[:collected] = Money.new(0)
    total_tickets[:facility] = Money.new(0)
    total_tickets[:processing] = Money.new(0)
    total_tickets[:paid] = 0
    total_tickets[:holds] = 0
    total_tickets[:display_class] = :report_summary_row

    productions.sort! { |p1, p2| p1.name <=> p2.name }
    productions.each { |production|
      subtotal = Hash.new
      ticket_classes = production.ticket_classes.sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
      ticket_classes.each { |tc| total_tickets[tc.class_code] = 0 }
      subtotal[:gross] = Money.new(0)
      subtotal[:collected] = Money.new(0)
      subtotal[:facility] = Money.new(0)
      subtotal[:processing] = Money.new(0)
      subtotal[:paid] = 0
      subtotal[:holds] = 0
      subtotal[:display_class] = :report_summary_row
      subtotal[:performance_code] = production.production_code
      # header row
      use_performances = restrict_to_performances.nil? ? production.performances : restrict_to_performances.select { |p|
        p.production.id == production.id
      }
      use_performances.sort { |x, y|
        (x.performance_date == y.performance_date) ?
          x.performance_time <=> y.performance_time :
          x.performance_date <=> y.performance_date
      }.each { |perf|
        settled_orders = perf.orders.select { |o| o.settled? }
        held_orders = perf.orders.select { |o| o.held? }
        paid_tickets = settled_orders.sum { |o| o.number_of_tickets }
        held_tickets = held_orders.sum { |o| o.number_of_tickets }
        max_ticket_price = perf.ticket_class_allocations.select { |tca|
          tca.available? && !tca.ticket_class.nil?
        }.max_by { |tca| tca.ticket_class.ticket_price }.ticket_class.ticket_price
        revenue = RevenueCalculator.for(settled_orders)
        gross = revenue.cash_collected.to_money
        collected = revenue.cash_reportable.to_money
        ticketing_fee = revenue.ticketing_fees.to_money
        processing_fee = revenue.processing_fees.to_money
        subtotal[:gross] += gross
        subtotal[:collected] += collected
        subtotal[:facility] += ticketing_fee
        subtotal[:processing] += processing_fee
        subtotal[:paid] += paid_tickets
        subtotal[:holds] += held_tickets
        row = { :performance_code => perf.performance_code,
                :performance_date => perf.performance_date,
                :performance_time => perf.performance_time,
                :display_class => :report_detail_row,
                :max_ticket => max_ticket_price.to_money }
        if breakdown_by_ticket_class then
          ticket_classes.each { |tc|
            class_qty = settled_orders.sum { |o| o.ticket_quantity_by_class(tc.class_code) }
            total_tickets[tc.class_code] += class_qty
            row[tc.class_code] = class_qty
          }

        end

        row[:paid] = paid_tickets
        row[:holds] = held_tickets
        row[:gross] = gross
        row[:collected] = collected
        row[:facility] = ticketing_fee
        row[:processing] = processing_fee
        row[:net] = collected - (ticketing_fee + processing_fee)
        report << row
      }
      subtotal[:net] = subtotal[:collected] - (subtotal[:facility] + subtotal[:processing])

      report << subtotal
      total_tickets[:gross] += subtotal[:gross]
      total_tickets[:collected] += subtotal[:collected]
      total_tickets[:facility] += subtotal[:facility]
      total_tickets[:processing] += subtotal[:processing]
      total_tickets[:paid] += subtotal[:paid]
      total_tickets[:holds] += subtotal[:holds]
    }

    total_tickets[:net] = total_tickets[:collected] - (total_tickets[:facility] + total_tickets[:processing])
    total_tickets[:performance_code] = "TOTAL"
    if productions.size > 1
      report << total_tickets
    end

    # Build headers, filtering out ticket classes with zero sales
    @headers = [:performance_code, :performance_date, :performance_time]
    if breakdown_by_ticket_class
      productions.first.ticket_classes
                 .sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
                 .each { |tc| @headers << tc.class_code if (total_tickets[tc.class_code] || 0) > 0 }
    end
    @headers += [:paid, :holds, :max_ticket, :gross, :collected, :facility, :processing, :net]

    [headers, report]
  end
end
