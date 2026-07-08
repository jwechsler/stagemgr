# Human-readable date ranges: "July 8 – July 15, 2026". Shows both years
# when the range crosses a year boundary, collapses single-day ranges, and
# tolerates an open end on either side.
module DateRangeDisplay
  module_function

  def format(from, to)
    return nil if from.nil? && to.nil?
    return from.strftime('%B %-d, %Y') if to.nil? || from == to
    return to.strftime('through %B %-d, %Y') if from.nil?
    return "#{from.strftime('%B %-d')} – #{to.strftime('%B %-d, %Y')}" if from.year == to.year

    "#{from.strftime('%B %-d, %Y')} – #{to.strftime('%B %-d, %Y')}"
  end
end
