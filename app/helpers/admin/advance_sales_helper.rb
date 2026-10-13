module Admin::AdvanceSalesHelper
  EMPTY_CELL = Admin::MembershipAnalysisHelper::EMPTY_CELL
  SAME_DAY_LABEL = 'Same day'.freeze
  TOO_EARLY_LABEL = 'Too early'.freeze
  EXTERNAL_SALES_TITLE = 'Sales recorded externally'.freeze

  # "42%", or a dash when there were no tickets to take a share of.
  def advance_sales_share(share)
    share.nil? ? EMPTY_CELL : "#{(share * 100).round}%"
  end

  IN_PROGRESS_DASH = [6, 4].freeze

  # One line per series: the percent of its final sales in hand at each
  # AdvanceSalesCurve::THRESHOLDS point. An in-progress series is dashed.
  def advance_sales_chart_data(series)
    series.map do |s|
      line = { name: s.label,
               data: AdvanceSalesCurve::THRESHOLDS.map { |d| [advance_sales_days_label(d), (s.curve.share_at(d) * 100).round(1)] } }
      s.in_progress? ? line.merge(dataset: { borderDash: IN_PROGRESS_DASH }) : line
    end
  end

  # "3 of 40" performances upcoming, or a dash for a finished series.
  def advance_sales_still_to_play(series)
    series.in_progress? ? "#{series.upcoming_performance_count} of #{series.performance_count}" : EMPTY_CELL
  end

  # A "2 upcoming" label for a run week with performances still to come.
  def advance_sales_week_marker(week)
    ui_label "#{week.upcoming_count} upcoming", variant: :secondary if week.upcoming_count.positive?
  end

  def advance_sales_days_label(days)
    days.zero? ? SAME_DAY_LABEL : "#{days}d"
  end

  # Column label for an AdvanceSalesCurve::BUCKETS window: "Same day",
  # "1–2d", or "30+d" when the window has no upper limit.
  def advance_sales_bucket_label(low, high)
    return SAME_DAY_LABEL if low.zero? && high&.zero?

    high.nil? ? "#{low}+d" : "#{low}–#{high}d"
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

  # Pace cell for the Upcoming House Counts table, read from the pace snapshot
  # on a HouseCount (refreshed on every recalculation and nightly): a dash with
  # no snapshot or nothing projectable, "Too early" when the share in hand is
  # too small to project, else
  # "~84 (84% of capacity)". The title explains the basis. A production whose
  # sales are recorded externally is never projected, so its dash carries a
  # title saying why.
  def house_count_pace_cell(house_count)
    if house_count.performance.production&.sales_recorded_externally?
      return content_tag(:span, EMPTY_CELL, title: EXTERNAL_SALES_TITLE)
    end
    return EMPTY_CELL if house_count.pace_as_of.nil? || house_count.pace_share.nil?

    title = house_count_pace_title(house_count)
    return content_tag(:span, TOO_EARLY_LABEL, title: title) if house_count.pace_too_early?

    content_tag(:span, house_count_pace_text(house_count), title: title)
  end

  private

  def house_count_pace_text(house_count)
    text = "~#{number_with_delimiter(house_count.projected_seats)}"
    pct = house_count.projected_pct_of_capacity
    pct ? "#{text} (#{(pct * 100).round}% of capacity)" : text
  end

  def house_count_pace_title(house_count)
    share = (house_count.pace_share.to_f * 100).round
    title = "Sold #{house_count.pace_sold} as of #{house_count.pace_as_of.strftime('%b %-d')}; " \
            "this house typically has #{share}% in hand #{house_count.pace_days_out} days out"
    house_count.pace_source == 'building' ? "#{title} (building-wide curve)" : title
  end
end
