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

    { target_tickets: target_tickets, target_revenue: target_revenue, aggregate_data: aggregate_data, projection: projection, comparison_summaries: comparison_summaries }
  end

  private

  def compute_projection(cutoff, extra_weeks: 0)
    return nil if target_production.closing_at.nil?

    anchor = target_production.first_playing_date
    presale_cutoff = anchor - 21.days

    # Total weeks in the run, plus any extension
    total_weeks = ((target_production.closing_at - presale_cutoff).to_i / 7) + 1 + extra_weeks

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

    # The body fills weeks 1 through (total_weeks - decline_tail.size)
    # The decline tail fills the final decline_tail.size weeks
    body_weeks = total_weeks - decline_tail.size

    # Project remaining weeks
    projected_cumulative = {}
    projected_remaining = 0.0
    (last_actual_week + 1..total_weeks).each do |week_num|
      key = "Week #{week_num}"
      if week_num <= body_weeks
        # Stretch the body (growth+plateau) across body_weeks
        interpolated = interpolate_curve(body, week_num, body_weeks)
      else
        # Map to the decline tail
        tail_index = week_num - body_weeks - 1
        interpolated = tail_index < decline_tail.size ? decline_tail[tail_index] : decline_tail.last
      end
      projected_week = (interpolated * ratio).round(2)
      projected_remaining += projected_week
      running_total += projected_week
      projected_cumulative[key] = running_total.round(2)
    end

    actual_total = actual_cumulative.values.last || 0.0

    {
      actual_cumulative: actual_cumulative,
      projected_cumulative: projected_cumulative,
      performance_ratio: ratio.round(2),
      projected_remaining: projected_remaining.round(2),
      projected_total: (actual_total + projected_remaining).round(2),
      actual_total: actual_total.round(2),
      extra_weeks: extra_weeks
    }
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
