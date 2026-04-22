# Single source of truth for "what did this scope of orders bring in?"
# Used by SalesByPerformanceReport, RateOfSalesJob, and TicketRevenueAnalysis
# so the three screens cannot drift against each other.
#
# REFUNDED and EXCHANGED orders are included by default — they net out via the
# offset payments written to the original order (see Payment#new_exchange_offset_payment).
class RevenueCalculator
  Result = Struct.new(
    :cash_collected,
    :cash_reportable,
    :ticketing_fees,
    :processing_fees,
    :ticket_count,
    :comp_count,
    :order_count,
    keyword_init: true
  ) do
    # Matches SalesByPerformanceReport's historical "net" column:
    # reportable cash minus fees. Uses cash_reportable (not cash_collected)
    # so membership/flex-pass payments — which are gross but not collected —
    # don't inflate the house's take-home figure.
    def net
      cash_reportable - ticketing_fees - processing_fees
    end

    def +(other)
      return self if other.nil?
      Result.new(
        cash_collected:   cash_collected   + other.cash_collected,
        cash_reportable:  cash_reportable  + other.cash_reportable,
        ticketing_fees:   ticketing_fees   + other.ticketing_fees,
        processing_fees:  processing_fees  + other.processing_fees,
        ticket_count:     ticket_count     + other.ticket_count,
        comp_count:       comp_count       + other.comp_count,
        order_count:      order_count      + other.order_count
      )
    end
  end

  ZERO = Result.new(
    cash_collected:  BigDecimal('0'),
    cash_reportable: BigDecimal('0'),
    ticketing_fees:  BigDecimal('0'),
    processing_fees: BigDecimal('0'),
    ticket_count:    0,
    comp_count:      0,
    order_count:     0
  ).freeze

  PRELOADS = [
    { payments: :payment_type },
    { ticket_line_items: :ticket_class },
    :service_line_items
  ].freeze

  # Compute totals for an arbitrary set of orders.
  #
  # @param orders [ActiveRecord::Relation, Enumerable<Order>] an AR relation (preferred — we'll preload) or a pre-loaded array
  # @param statuses [Array<String>] status filter applied when `orders` is a relation (default: SETTLED_STATUSES)
  def self.for(orders, statuses: Order::SETTLED_STATUSES)
    new(orders, statuses: statuses).compute
  end

  # Convenience: all settled TicketOrders across a production.
  def self.for_production(production, statuses: Order::SETTLED_STATUSES)
    scope = TicketOrder.joins(:performance).where(performances: { production_id: production.id })
    self.for(scope, statuses: statuses)
  end

  # Convenience: settled TicketOrders for a production on a single calendar day
  # (keyed on Order#created_at, matching RateOfSalesJob semantics).
  def self.for_production_on_day(production_id, date, statuses: Order::SETTLED_STATUSES)
    scope = TicketOrder
              .joins(:performance)
              .where(performances: { production_id: production_id })
              .where(created_at: date.all_day)
    self.for(scope, statuses: statuses)
  end

  def initialize(orders, statuses: Order::SETTLED_STATUSES)
    @orders_input = orders
    @statuses = statuses
  end

  def compute
    orders = resolve_orders
    return ZERO.dup if orders.empty?

    cash_collected  = 0.0
    cash_reportable = 0.0
    ticketing_fees  = 0.0
    processing_fees = 0.0
    ticket_count    = 0
    comp_count      = 0

    orders.each do |o|
      payments = o.payments.to_a
      cash_collected  += payments.sum(&:amount)
      cash_reportable += payments.select { |p| p.report_as_sales_collected? }.sum(&:amount)
      ticketing_fees  += o.ticketing_fee.to_f
      processing_fees += o.processing_fee.to_f

      if o.respond_to?(:ticket_line_items)
        tlis = o.ticket_line_items.to_a
        comps = tlis.select(&:complimentary?).sum(&:ticket_count)
        comp_count   += comps
        ticket_count += tlis.sum(&:ticket_count) - comps
      end
    end

    Result.new(
      cash_collected:  cc(cash_collected),
      cash_reportable: cc(cash_reportable),
      ticketing_fees:  cc(ticketing_fees),
      processing_fees: cc(processing_fees),
      ticket_count:    ticket_count,
      comp_count:      comp_count,
      order_count:     orders.size
    )
  end

  private

  def resolve_orders
    if @orders_input.respond_to?(:where) && @orders_input.respond_to?(:includes)
      @orders_input.where(status: @statuses).includes(*PRELOADS).to_a
    else
      @orders_input.select { |o| @statuses.include?(o.status) }
    end
  end

  def cc(n)
    CurrencyUtils.float_to_currency_decimal(n)
  end
end
