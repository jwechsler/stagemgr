class RoyaltyReport < Report
  attr_accessor :productions
  attr_accessor :breakdown_by_ticket_class

  def initialize(production_list, breakdown_by_ticket_class = true, reporting_user_id = nil)
    @productions = production_list.map { |prod|
      prod.is_a?(Production) ? prod : Production.find(prod)
    }
    @breakdown_by_ticket_class = @productions.size == 1 ? breakdown_by_ticket_class : false
    super([], reporting_user_id)
  end

  def create
    report = []
    total_tickets = Hash.new
    total_tickets[:gross] = Money.new(0)
    total_tickets[:processing] = Money.new(0)
    total_tickets[:paid] = 0
    total_tickets[:display_class] = :report_summary_row

    # Pre-scan to find ticket classes with sales > 0 across the run
    active_ticket_classes = find_active_ticket_classes

    productions.sort! { |p1, p2| p1.name <=> p2.name }
    productions.each do |production|
      subtotal = Hash.new
      ticket_classes = production.ticket_classes.sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
      prod_active_classes = ticket_classes.select { |tc| active_ticket_classes.include?(tc.id) }

      prod_active_classes.each { |tc| total_tickets[tc.class_code] = 0 }
      subtotal[:gross] = Money.new(0)
      subtotal[:processing] = Money.new(0)
      subtotal[:paid] = 0
      subtotal[:display_class] = :report_summary_row
      subtotal[:performance_code] = production.production_code

      production.performances.sort { |x, y|
        (x.performance_date == y.performance_date) ?
          x.performance_time <=> y.performance_time :
          x.performance_date <=> y.performance_date
      }.each do |perf|
        settled_orders = perf.orders.select { |o| o.settled? }
        paid_tickets = settled_orders.sum { |o| o.number_of_tickets }
        gross = settled_orders.sum { |o| o.respond_to?(:royalty_gross) ? o.royalty_gross : 0 }.to_money
        processing_fee = settled_orders.sum { |o| o.processing_fee }.to_money

        subtotal[:gross] += gross
        subtotal[:processing] += processing_fee
        subtotal[:paid] += paid_tickets

        row = {
          performance_code: perf.performance_code,
          performance_date: perf.performance_date,
          performance_time: perf.performance_time,
          display_class: :report_detail_row
        }

        if breakdown_by_ticket_class
          prod_active_classes.each do |tc|
            class_qty = settled_orders.sum { |o|
              o.respond_to?(:ticket_quantity_by_class) ? o.ticket_quantity_by_class(tc.class_code) : 0
            }
            total_tickets[tc.class_code] = (total_tickets[tc.class_code] || 0) + class_qty
            row[tc.class_code] = class_qty
          end
        end

        row[:paid] = paid_tickets
        row[:gross] = gross
        row[:processing] = processing_fee
        row[:net] = gross - processing_fee

        royalty_pct = production.royalty_percent || 0
        row[:royalty] = (row[:net] * (royalty_pct / 100.0)).to_money

        report << row
      end

      subtotal[:net] = subtotal[:gross] - subtotal[:processing]

      royalty_pct = production.royalty_percent || 0
      subtotal[:royalty] = (subtotal[:net] * (royalty_pct / 100.0)).to_money

      report << subtotal
      total_tickets[:gross] += subtotal[:gross]
      total_tickets[:processing] += subtotal[:processing]
      total_tickets[:paid] += subtotal[:paid]
    end

    # Build total row
    total_tickets[:net] = total_tickets[:gross] - total_tickets[:processing]

    royalty_pct = productions.first.royalty_percent || 0
    total_tickets[:royalty] = (total_tickets[:net] * (royalty_pct / 100.0)).to_money

    total_tickets[:performance_code] = "TOTAL"
    report << total_tickets if productions.size > 1

    # Build headers
    build_headers(active_ticket_classes)

    # Insert face value sub-header row for CSV (when ticket class columns are present)
    if breakdown_by_ticket_class
      face_value_row = { performance_code: 'Face Value' }
      productions.first.ticket_classes
                 .select { |tc| active_ticket_classes.include?(tc.id) }
                 .sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
                 .each { |tc|
        face_value_row[tc.class_code] =
          tc.royalty_price.to_money
      }
      report.unshift(face_value_row)
    end

    [headers, report]
  end

  private

  def find_active_ticket_classes
    active_ids = Set.new
    productions.each do |production|
      production.performances.each do |perf|
        perf.orders.select(&:settled?).each do |order|
          next unless order.respond_to?(:ticket_line_items)

          order.ticket_line_items.each do |tli|
            active_ids.add(tli.ticket_class_id) if tli.ticket_count > 0
          end
        end
      end
    end
    active_ids
  end

  def build_headers(active_ticket_classes)
    @headers = [:performance_code, :performance_date, :performance_time]
    if breakdown_by_ticket_class
      productions.first.ticket_classes
                 .select { |tc| active_ticket_classes.include?(tc.id) }
                 .sort { |t1, t2| t2.ticket_price <=> t1.ticket_price }
                 .each { |tc| @headers << tc.class_code }
    end
    @headers += [:paid, :gross, :processing, :net, :royalty]
  end
end
