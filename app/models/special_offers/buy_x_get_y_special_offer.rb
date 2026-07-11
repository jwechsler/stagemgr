class BuyXGetYSpecialOffer < SpecialOffer
  validates :buy_quantity, :get_quantity,
            numericality: { only_integer: true, greater_than: 0 }

  # Flattens qualifying line items into per-ticket units so a free ticket can
  # fall inside a multi-count line item. Returns the free units, cheapest first:
  # every full group of (buy_quantity + get_quantity) qualifying tickets earns
  # get_quantity free.
  def free_units(order)
    units = applicable_line_items(order, false)
            .select { |li| li.ticket_count.positive? }
            .flat_map do |li|
      unit_royalty = li.royalty_total / li.ticket_count
      Array.new(li.ticket_count) { { line_item: li, price: li.price, royalty: unit_royalty } }
    end
    units.sort_by! { |u| u[:price] }
    free_count = (units.size / (buy_quantity + get_quantity)) * get_quantity
    units.first(free_count)
  end

  def calculate_discount(order)
    (free_units(order).sum { |u| u[:price] } * -1).round(2)
  end

  def calculate_royalty_discount(order)
    (free_units(order).sum { |u| u[:royalty] } * -1).round(2)
  end

  # { ticket_line_item.id => number of free tickets in that line }
  def free_ticket_counts(order)
    free_units(order).each_with_object(Hash.new(0)) { |u, h| h[u[:line_item].id] += 1 }
  end

  def description(order)
    "Buy #{buy_quantity} get #{get_quantity} free (#{free_units(order).size} free) #{super}"
  end

  def to_s
    "Buy #{buy_quantity} get #{get_quantity} free / #{super}"
  end
end
