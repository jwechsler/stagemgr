class RateOfSalesAnalysis
  attr_reader :target_production, :comparison_productions

  def initialize(target_production, comparison_productions)
    @target_production = target_production
    @comparison_productions = comparison_productions
  end

  def compute(extra_weeks: 0)
    cutoff = Date.today.beginning_of_week
    target_tickets = weekly_pct_change_for(target_production, cutoff: cutoff)
    target_revenue = weekly_pct_change_for(target_production, cutoff: cutoff, field: :gross_sales)
    comparison_series = comparison_productions.map { |p| weekly_pct_change_for(p) }
    aggregate_data = aggregate_series(comparison_series)
    projection = compute_projection(cutoff, extra_weeks: extra_weeks)

    comparison_summaries = comparison_productions.map do |p|
      weekly = weekly_totals_for(p, field: :gross_sales)
      total_revenue = weekly.values.sum
      num_weeks = extract_max_week(weekly)
      { production: p, total_revenue: total_revenue, num_weeks: num_weeks }
    end

    target_weekly_rev = weekly_totals_for(target_production, cutoff: cutoff, field: :gross_sales)
    target_summary = {
      production: target_production,
      total_revenue: target_weekly_rev.values.sum,
      num_weeks: extract_max_week(target_weekly_rev)
    }

    daily_rolling = daily_rolling_revenue_for(target_production, cutoff: Date.yesterday)
    comparison_daily_rolling = if comparison_productions.size == 1
      daily_rolling_revenue_for(comparison_productions.first, cutoff: Date.today)
    end
    insights = compute_insights(cutoff, target_tickets, target_revenue, aggregate_data, daily_rolling)

    { target_tickets: target_tickets, target_revenue: target_revenue, aggregate_data: aggregate_data, projection: projection, comparison_summaries: comparison_summaries, target_summary: target_summary, insights: insights, daily_rolling: daily_rolling, comparison_daily_rolling: comparison_daily_rolling }
  end

  private

  def compute_projection(cutoff, extra_weeks: 0)
    return nil if target_production.closing_at.nil?

    anchor = target_production.first_playing_date
    presale_cutoff = anchor - 21.days

    # Baseline run length (no extension). The body stretch uses this so that
    # extending the run doesn't retroactively revalue already-projected weeks.
    baseline_total_weeks = ((target_production.closing_at - presale_cutoff).to_i / 7) + 1
    total_weeks = baseline_total_weeks + extra_weeks

    # Target's actual weekly revenue (through cutoff)
    target_weekly = weekly_totals_for(target_production, cutoff: cutoff, field: :gross_sales)
    return nil if target_weekly.empty?

    last_actual_week = extract_max_week(target_weekly)

    # Nothing to project if the show is already over
    return nil if last_actual_week >= total_weeks

    # Aggregate average weekly revenue (raw $, full runs) across comparison productions
    comparison_weekly = comparison_productions.map { |p| weekly_totals_for(p, field: :gross_sales) }
    aggregate_weekly_avg = average_weekly_totals(comparison_weekly)
    return nil if aggregate_weekly_avg.empty?

    # Compute exponentially-weighted performance ratio over overlapping weeks
    ratio = weighted_performance_ratio(target_weekly, aggregate_weekly_avg)
    return nil if ratio.nil? || ratio <= 0

    # Build actual cumulative revenue
    actual_cumulative = {}
    running_total = 0.0
    target_weekly.each do |label, amount|
      running_total += amount
      actual_cumulative[label] = running_total.round(2)
    end
    actual_total = actual_cumulative.values.last || 0.0

    # Seat-inventory revenue cap shared by both projections
    avg_price = avg_ticket_price_to_date(target_production)
    remaining_rev_budget_initial = remaining_revenue_budget(target_production, avg_price)

    # Build the historical lifecycle curve and split into body + decline tail.
    # The body (growth + plateau) gets stretched to fill the projected run;
    # the decline tail is appended at the end unchanged.
    hist_curve = aggregate_weekly_avg.select { |k, _| k =~ /^Week \d+$/ }
                                     .sort_by { |k, _| k[/\d+/].to_i }
                                     .map(&:last)
    # Drop trailing partial/straggler weeks (near-zero revenue after show closes)
    peak_val = hist_curve.max || 0
    hist_curve.pop while hist_curve.size > 1 && hist_curve.last < peak_val * 0.01

    body, decline_tail = split_curve_at_decline(hist_curve)

    # Body mapping is pinned to the baseline run (no extension), so projected
    # weeks that already existed before the extension keep their values. The
    # decline tail absorbs the extra weeks by stretching across a longer span.
    body_weeks = baseline_total_weeks - decline_tail.size
    extended_tail_weeks = decline_tail.size + extra_weeks

    # Project remaining weeks (historical-scaled)
    projected_cumulative = {}
    projected_remaining = 0.0
    remaining_budget = remaining_rev_budget_initial
    capacity_clipped = false
    (last_actual_week + 1..total_weeks).each do |week_num|
      key = "Week #{week_num}"
      if week_num <= body_weeks
        # Stretch the body (growth+plateau) across body_weeks (baseline only)
        interpolated = interpolate_curve(body, week_num, body_weeks)
      elsif decline_tail.any?
        # Stretch the decline tail across (tail.size + extra_weeks) weeks, so
        # extension weeks interpolate within the tail rather than re-stretching
        # the body.
        tail_pos = week_num - body_weeks  # 1-based index into extended tail
        interpolated = interpolate_curve(decline_tail, tail_pos, extended_tail_weeks)
      else
        # No decline tail — plateau at the last body value for extension weeks
        interpolated = body.last || 0.0
      end
      projected_week = interpolated * ratio
      if projected_week > remaining_budget
        projected_week = [remaining_budget, 0.0].max
        capacity_clipped = true
      end
      projected_week = projected_week.round(2)
      remaining_budget -= projected_week
      projected_remaining += projected_week
      running_total += projected_week
      projected_cumulative[key] = running_total.round(2)
    end

    # Self-scaled alternate projection: anchor on current show's last actual
    # weekly revenue, grow by historical pct-change shape offset by the
    # target's recent pct-change advantage/deficit vs that shape.
    alternate = compute_alternate_projection(
      cutoff: cutoff,
      target_weekly: target_weekly,
      last_actual_week: last_actual_week,
      total_weeks: total_weeks,
      actual_total: actual_total,
      remaining_rev_budget_initial: remaining_rev_budget_initial
    )

    {
      actual_cumulative: actual_cumulative,
      projected_cumulative: projected_cumulative,
      performance_ratio: ratio.round(2),
      projected_remaining: projected_remaining.round(2),
      projected_total: (actual_total + projected_remaining).round(2),
      actual_total: actual_total.round(2),
      extra_weeks: extra_weeks,
      alternate_cumulative: alternate[:alternate_cumulative],
      alternate_remaining: alternate[:alternate_remaining],
      alternate_total: alternate[:alternate_total],
      alternate_momentum_pct: alternate[:alternate_momentum_pct],
      alternate_momentum_raw_pct: alternate[:alternate_momentum_raw_pct],
      alternate_momentum_window: alternate[:alternate_momentum_window],
      alternate_anchor: alternate[:alternate_anchor],
      alternate_initial_budget: alternate[:alternate_initial_budget],
      capacity_clipped: capacity_clipped || alternate[:capacity_clipped],
      avg_ticket_price: avg_price&.round(2),
      remaining_seats: remaining_seats_across_future_performances(target_production)
    }
  end

  # Alternate projection (pure momentum): anchor on the target's recent 7-day
  # rolling revenue and apply the target's own recent week-over-week pct
  # change forward. No historical-show scaling — the projection reflects the
  # current show's observed trajectory, capped by remaining seat inventory.
  def compute_alternate_projection(cutoff:, target_weekly:, last_actual_week:, total_weeks:, actual_total:, remaining_rev_budget_initial:)
    # Anchor on the 7-day rolling revenue. More stable than the last weekly
    # bucket, which is typically partial since presale_cutoff week boundaries
    # don't align with the start-of-week cutoff used for actuals.
    daily_rolling = daily_rolling_revenue_for(target_production, cutoff: Date.yesterday)
    anchor_weekly = daily_rolling.values.last.to_f
    if anchor_weekly <= 0
      anchor_weekly = target_weekly["Week #{last_actual_week}"].to_f
    end

    target_rev_pct = weekly_pct_change_for(target_production, cutoff: cutoff, field: :gross_sales)
    momentum_pct, momentum_window = compute_momentum(target_rev_pct)
    # Keep the forward rate within plausible bounds so a single early-run
    # spike doesn't produce runaway growth or decay.
    momentum_pct_clamped = momentum_pct.clamp(-25.0, 25.0)

    alt_cumulative = {}
    alt_remaining = 0.0
    cum = actual_total
    prev_weekly = anchor_weekly
    remaining_budget = remaining_rev_budget_initial
    capacity_clipped = false

    (last_actual_week + 1..total_weeks).each do |_week_num|
      key = "Week #{_week_num}"
      weekly = prev_weekly * (1 + momentum_pct_clamped / 100.0)
      weekly = 0.0 if weekly < 0
      if weekly > remaining_budget
        weekly = [remaining_budget, 0.0].max
        capacity_clipped = true
      end
      weekly = weekly.round(2)
      remaining_budget -= weekly
      alt_remaining += weekly
      cum += weekly
      alt_cumulative[key] = cum.round(2)
      prev_weekly = weekly
    end

    {
      alternate_cumulative: alt_cumulative,
      alternate_remaining: alt_remaining.round(2),
      alternate_total: (actual_total + alt_remaining).round(2),
      alternate_momentum_pct: momentum_pct_clamped.round(1),
      alternate_momentum_raw_pct: momentum_pct.round(1),
      alternate_momentum_window: momentum_window,
      alternate_anchor: anchor_weekly.round(2),
      alternate_initial_budget: remaining_rev_budget_initial.finite? ? remaining_rev_budget_initial.round(2) : nil,
      capacity_clipped: capacity_clipped
    }
  end

  # Returns [momentum_pct, window_size]. Momentum is the median of the
  # target's own week-over-week pct changes over the last 3 non-"Pre-sales"
  # weeks. Median over mean so a single early-week spike (e.g., opening
  # surge) doesn't dominate. Returns [0.0, 0] if fewer than 2 weeks exist.
  def compute_momentum(target_rev_pct)
    keys = target_rev_pct.keys.grep(/^Week \d+$/).sort_by { |k| k[/\d+/].to_i }
    recent = keys.last(3)
    return [0.0, 0] if recent.size < 2

    values = recent.map { |k| target_rev_pct[k] }.sort
    mid = values.size / 2
    momentum = values.size.odd? ? values[mid] : (values[mid - 1] + values[mid]) / 2.0
    [momentum, recent.size]
  end

  # Realized average ticket price across all sales to date.
  def avg_ticket_price_to_date(production)
    totals = production.rate_of_sales.pluck(:gross_sales, :total_single_tickets)
    total_rev = totals.sum { |r, _| r.to_f }
    total_tix = totals.sum { |_, t| t.to_i }
    return nil if total_tix <= 0
    total_rev / total_tix
  end

  # Sum of seats_left across all performances that have not yet occurred.
  def remaining_seats_across_future_performances(production)
    today = Date.today
    production.performances
              .select { |p| p.performance_date && p.performance_date >= today }
              .sum { |p| [p.number_of_seats_left.to_i, 0].max }
  end

  # Upper bound on remaining revenue = remaining future seats * avg price.
  # Returns Float::INFINITY when we can't derive a price (no sales yet).
  def remaining_revenue_budget(production, avg_price)
    return Float::INFINITY if avg_price.nil? || avg_price <= 0
    remaining_seats_across_future_performances(production) * avg_price
  end

  def compute_insights(cutoff, target_tickets_pct, target_revenue_pct, aggregate_pct, daily_rolling)
    insights = {}

    # Raw weekly totals for the current show
    target_ticket_totals = weekly_totals_for(target_production, cutoff: cutoff)
    target_revenue_totals = weekly_totals_for(target_production, cutoff: cutoff, field: :gross_sales)

    # Aggregate raw weekly totals across comparison productions
    comp_ticket_series = comparison_productions.map { |p| weekly_totals_for(p) }
    comp_revenue_series = comparison_productions.map { |p| weekly_totals_for(p, field: :gross_sales) }
    agg_ticket_totals = average_weekly_totals(comp_ticket_series)
    agg_revenue_totals = average_weekly_totals(comp_revenue_series)

    # 1. Average tickets/week and revenue/week vs historical
    target_week_keys = target_ticket_totals.keys.grep(/^Week \d+$/)
    if target_week_keys.any?
      target_avg_tickets = target_week_keys.sum { |k| target_ticket_totals[k] } / target_week_keys.size.to_f
      target_avg_revenue = target_week_keys.sum { |k| target_revenue_totals[k] || 0 } / target_week_keys.size.to_f

      overlapping_keys = target_week_keys & agg_ticket_totals.keys
      if overlapping_keys.any?
        hist_avg_tickets = overlapping_keys.sum { |k| agg_ticket_totals[k] } / overlapping_keys.size.to_f
        hist_avg_revenue = overlapping_keys.sum { |k| agg_revenue_totals[k] || 0 } / overlapping_keys.size.to_f
      else
        hist_avg_tickets = nil
        hist_avg_revenue = nil
      end

      insights[:avg_tickets_per_week] = target_avg_tickets.round(1)
      insights[:avg_revenue_per_week] = target_avg_revenue.round(2)
      insights[:hist_avg_tickets_per_week] = hist_avg_tickets&.round(1)
      insights[:hist_avg_revenue_per_week] = hist_avg_revenue&.round(2)
    end

    # 2. Ticket growth comparison — use last 3 weeks only to avoid early
    # spikes (e.g., 500% when going from near-zero to real sales) that
    # make the full-run average meaningless.
    overlapping_pct = (target_tickets_pct.keys & aggregate_pct.keys) - ["Pre-sales"]
    compare_keys = overlapping_pct.sort_by { |k| k[/\d+/].to_i }.last(3)
    if compare_keys.size >= 2
      target_avg_pct = compare_keys.sum { |k| target_tickets_pct[k] } / compare_keys.size.to_f
      hist_avg_pct = compare_keys.sum { |k| aggregate_pct[k] } / compare_keys.size.to_f
      insights[:ticket_growth_avg] = target_avg_pct.round(1)
      insights[:hist_ticket_growth_avg] = hist_avg_pct.round(1)
      insights[:ticket_growth_diff] = (target_avg_pct - hist_avg_pct).round(1)
      insights[:growth_window] = compare_keys.size
    end

    # 3. Revenue growth comparison — same recent window
    overlapping_rev = (target_revenue_pct.keys & aggregate_pct.keys) - ["Pre-sales"]
    rev_compare_keys = overlapping_rev.sort_by { |k| k[/\d+/].to_i }.last(3)
    if rev_compare_keys.size >= 2
      target_rev_avg_pct = rev_compare_keys.sum { |k| target_revenue_pct[k] } / rev_compare_keys.size.to_f
      hist_rev_avg_pct = rev_compare_keys.sum { |k| aggregate_pct[k] } / rev_compare_keys.size.to_f
      insights[:revenue_growth_avg] = target_rev_avg_pct.round(1)
      insights[:revenue_growth_diff] = (target_rev_avg_pct - hist_rev_avg_pct).round(1)
    end

    # 4. Current trajectory — compare recent 7-day rolling avg vs prior 7-day rolling avg
    rolling_values = daily_rolling.values
    if rolling_values.size >= 14
      recent_avg = rolling_values.last(7).sum / 7.0
      prior_avg  = rolling_values[-14..-8].sum / 7.0

      if prior_avg > 0
        trajectory_pct = ((recent_avg - prior_avg) / prior_avg * 100).round(1)
        insights[:trajectory] = if trajectory_pct > 2
                                   :increasing
                                 elsif trajectory_pct < -2
                                   :decreasing
                                 else
                                   :steady
                                 end
        insights[:trajectory_recent_avg] = recent_avg.round(2)
        insights[:trajectory_prior_avg]  = prior_avg.round(2)
        insights[:trajectory_pct_change] = trajectory_pct
      end
    end

    # 5. Performance ratio (revenue level vs historical)
    if insights[:hist_avg_revenue_per_week] && insights[:hist_avg_revenue_per_week] > 0
      insights[:performance_pct] = ((insights[:avg_revenue_per_week] / insights[:hist_avg_revenue_per_week]) * 100).round(0)
    end

    # 6. Lifecycle position — where is the show in its run vs historical peak?
    if target_week_keys&.any? && agg_revenue_totals.any? && target_production.closing_at.present?
      current_week = target_week_keys.map { |k| k[/\d+/].to_i }.max

      anchor = target_production.first_playing_date
      presale_cutoff = anchor - 21.days
      total_weeks = ((target_production.closing_at - presale_cutoff).to_i / 7) + 1

      # Find historical peak position normalized to fraction of run
      hist_week_data = agg_revenue_totals.select { |k, _| k =~ /^Week \d+$/ }
      if hist_week_data.any? && total_weeks > 0
        peak_week_num = hist_week_data.max_by { |_, v| v }.first[/\d+/].to_i
        hist_total_weeks = hist_week_data.keys.map { |k| k[/\d+/].to_i }.max

        current_position = current_week.to_f / total_weeks
        peak_position = peak_week_num.to_f / hist_total_weeks

        insights[:lifecycle] = if current_position < peak_position - 0.05
                                 :growth
                               elsif current_position <= peak_position + 0.10
                                 :plateau
                               else
                                 :decline
                               end
        insights[:lifecycle_week] = current_week
        insights[:lifecycle_total_weeks] = total_weeks
        insights[:lifecycle_peak_week] = (peak_position * total_weeks).round(0).to_i
      end
    end

    insights
  end

  def extract_max_week(weekly_data)
    weekly_data.keys.grep(/^Week (\d+)$/) { $1.to_i }.max || 0
  end

  # Averages raw weekly totals across multiple productions by week label
  def average_weekly_totals(series_list)
    return {} if series_list.empty?

    all_labels = series_list.flat_map(&:keys).uniq
    ordered_labels = sort_week_labels(all_labels)

    result = {}
    ordered_labels.each do |label|
      values = series_list.filter_map { |s| s[label] if s[label] && s[label] > 0 }
      next if values.empty?
      result[label] = values.sum / values.size.to_f
    end
    result
  end

  # Exponentially-weighted ratio of target vs aggregate weekly revenue
  # Recent weeks weighted more heavily (decay factor 0.7)
  def weighted_performance_ratio(target_weekly, aggregate_weekly)
    decay = 0.7
    overlapping = []

    target_weekly.each do |label, target_val|
      next if label == "Pre-sales" # skip pre-sales for ratio since it's a collapsed bucket
      agg_val = aggregate_weekly[label]
      next if agg_val.nil? || agg_val <= 0 || target_val <= 0
      overlapping << { target: target_val, aggregate: agg_val }
    end

    return nil if overlapping.empty?

    # Most recent week gets highest weight
    weighted_sum = 0.0
    weight_total = 0.0
    overlapping.each_with_index do |pair, i|
      weight = decay**(overlapping.size - 1 - i)
      weighted_sum += (pair[:target] / pair[:aggregate]) * weight
      weight_total += weight
    end

    weight_total > 0 ? weighted_sum / weight_total : nil
  end

  # Returns a hash of { "M/D/YY" => rolling_7day_sum } for the target production's daily revenue
  def daily_rolling_revenue_for(production, cutoff:)
    anchor = production.first_playing_date
    presale_cutoff = anchor - 21.days

    records = production.rate_of_sales
                        .where("day_of_sale <= ?", cutoff)
                        .pluck(:day_of_sale, :gross_sales)

    return {} if records.empty?

    daily_sales = records.each_with_object({}) do |(day, sales), h|
      h[day] = sales.to_f
    end

    start_date = presale_cutoff
    last_sale = records.map(&:first).max
    end_date = [cutoff, last_sale].min

    result = {}
    (start_date..end_date).each do |date|
      rolling_sum = (0..6).sum { |i| daily_sales[date - i.days] || 0.0 }
      result[date.strftime("%-m/%-d/%y")] = rolling_sum.round(2)
    end

    result
  end

  # Returns a hash of { "Pre-sales" => pct, "Week 1" => pct, ... }
  # representing % change in ticket sales week over week
  def weekly_pct_change_for(production, cutoff: nil, field: :total_single_tickets)
    weekly_totals = weekly_totals_for(production, cutoff: cutoff, field: field)
    compute_pct_changes(weekly_totals)
  end

  # Returns an ordered hash of { week_label => total }
  def weekly_totals_for(production, cutoff: nil, field: :total_single_tickets)
    anchor = production.first_playing_date
    presale_cutoff = anchor - 21.days

    scope = production.rate_of_sales.order(:day_of_sale)
    scope = scope.where("day_of_sale < ?", cutoff) if cutoff
    records = scope
    return {} if records.empty?

    buckets = Hash.new(0)

    records.each do |ros|
      day = ros.day_of_sale
      value = ros.send(field).to_f

      if day < presale_cutoff
        buckets["Pre-sales"] += value
      else
        week_num = ((day - presale_cutoff).to_i / 7) + 1
        buckets["Week #{week_num}"] += value
      end
    end

    # Return in order: Pre-sales first, then Week 1, 2, 3...
    ordered = ActiveSupport::OrderedHash.new
    ordered["Pre-sales"] = buckets["Pre-sales"] if buckets.key?("Pre-sales")
    max_week = buckets.keys.grep(/^Week (\d+)$/) { $1.to_i }.max || 0
    (1..max_week).each do |n|
      key = "Week #{n}"
      ordered[key] = buckets[key] if buckets.key?(key)
    end

    ordered
  end

  # Converts weekly totals to % change from previous week
  # Returns { week_label => pct_change } (first data point has no change, shown as 0)
  def compute_pct_changes(weekly_totals)
    result = {}
    prev_value = nil

    weekly_totals.each do |label, total|
      if prev_value.nil?
        result[label] = 0.0
      elsif prev_value > 0
        result[label] = ((total - prev_value).to_f / prev_value * 100).round(1)
      end
      # Skip if prev_value was 0 (don't include infinite % change)
      prev_value = total
    end

    result
  end

  # Averages % changes across multiple production series by week label
  # Excludes weeks where a production had zero sales (already excluded by compute_pct_changes)
  def aggregate_series(series_list)
    return {} if series_list.empty?

    # Collect all week labels in order
    all_labels = series_list.flat_map(&:keys).uniq
    ordered_labels = sort_week_labels(all_labels)

    result = {}
    ordered_labels.each do |label|
      values = series_list.filter_map { |s| s[label] }
      next if values.empty?
      result[label] = (values.sum / values.size.to_f).round(1)
    end

    result
  end

  # Split a revenue curve into body (growth+plateau) and decline tail.
  # The decline starts at the point where revenue drops and never recovers
  # to the previous level — i.e., sustained decline through end of run.
  def split_curve_at_decline(curve)
    return [curve, []] if curve.size < 3

    # Find the peak index
    peak_idx = curve.index(curve.max)

    # Find where sustained decline begins: from after the peak, look for
    # the first point where every subsequent value is lower than the one before.
    # The peak itself stays in the body.
    decline_start = nil
    ((peak_idx + 1)...curve.size).each do |i|
      remaining = curve[i..-1]
      if remaining.size >= 2 && remaining.each_cons(2).all? { |a, b| b <= a }
        decline_start = i
        break
      end
    end
    # If there's only one point after peak that declines, include it as decline
    if decline_start.nil? && peak_idx < curve.size - 1 && curve[peak_idx + 1] < curve[peak_idx]
      decline_start = peak_idx + 1
    end

    if decline_start && decline_start < curve.size - 1
      body = curve[0...decline_start]
      tail = curve[decline_start..-1]
      # Ensure body has at least 2 points for interpolation
      if body.size < 2
        [curve, []]
      else
        [body, tail]
      end
    else
      [curve, []]
    end
  end

  # Interpolate a value from the historical curve stretched to fit total_weeks.
  # Maps week_num (1-based) onto the historical curve using linear interpolation.
  # Example: if history has 8 points and total_weeks is 12, week 9 of 12
  # maps to position 0.727 of the curve (between historical points 5 and 6).
  def interpolate_curve(hist_curve, week_num, total_weeks)
    return 0.0 if hist_curve.empty?
    return hist_curve.first if hist_curve.size == 1

    # Map week position (0-based) to a position on the historical curve
    position = (week_num - 1).to_f / (total_weeks - 1) * (hist_curve.size - 1)
    lower = position.floor
    upper = position.ceil

    # Clamp to curve bounds
    lower = [[lower, 0].max, hist_curve.size - 1].min
    upper = [[upper, 0].max, hist_curve.size - 1].min

    return hist_curve[lower] if lower == upper

    # Linear interpolation between the two nearest points
    fraction = position - lower
    hist_curve[lower] * (1 - fraction) + hist_curve[upper] * fraction
  end

  def sort_week_labels(labels)
    labels.sort_by do |label|
      if label == "Pre-sales"
        -1
      elsif label =~ /^Week (\d+)$/
        $1.to_i
      else
        999
      end
    end
  end
end
