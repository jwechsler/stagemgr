module Admin::AdvanceSalesHelper
  EMPTY_CELL = Admin::MembershipAnalysisHelper::EMPTY_CELL
  SAME_DAY_LABEL = 'Same day'.freeze

  # "42%", or a dash when there were no tickets to take a share of.
  def advance_sales_share(share)
    share.nil? ? EMPTY_CELL : "#{(share * 100).round}%"
  end

  # One line per series: the percent of its final sales in hand at each
  # AdvanceSalesCurve::THRESHOLDS point.
  def advance_sales_chart_data(series)
    series.map do |s|
      { name: s.label,
        data: AdvanceSalesCurve::THRESHOLDS.map { |d| [advance_sales_days_label(d), (s.curve.share_at(d) * 100).round(1)] } }
    end
  end

  def advance_sales_days_label(days)
    days.zero? ? SAME_DAY_LABEL : "#{days}d"
  end

  # Weeks count from the production's first playing date: index 0 is
  # "Week 1", -1 is "Week before", and the floor bucket is "Earlier".
  def advance_sales_week_label(week)
    return 'Earlier' if week.index <= AdvanceSalesAnalysis::PRE_RUN_WEEK_FLOOR
    return 'Week before' if week.index == -1

    "Week #{week.index + 1}"
  end

  # "12.4 days", or a dash for a week that sold nothing.
  def advance_sales_lead(avg_days)
    avg_days.nil? ? EMPTY_CELL : "#{avg_days.round(1)} days"
  end

  def advance_sales_count(count)
    number_with_delimiter(count)
  end
end
