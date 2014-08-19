module PerformancesHelper
  def price_range(performance)
    visible = performance.ticket_class_allocations.select { |tca| tca.available? && tca.ticket_class.web_visible? && tca.ticket_class.holds_seats? }

    unless visible.empty?
      min_price = visible.first.ticket_class.ticket_price
      max_price = min_price
      visible.each do |tca|
        min_price = [tca.ticket_class.ticket_price, min_price].min
        max_price = [max_price, tca.ticket_class.ticket_price].max
      end
      display_min = min_price.to_money
      display_max = max_price.to_money

      price_range = raw "<span class=\"price_range\">#{display_min.format(:no_cents_if_whole=>true)}"
      price_range += raw "-#{display_max.format(:no_cents_if_whole=>true)}" unless max_price == min_price
      price_range += raw "</span>"
    else
      price_range = ''
    end
  end
end
