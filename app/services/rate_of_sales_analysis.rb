class RateOfSalesAnalysis
  attr_reader :target_production, :comparison_productions

  # Sentinel "field" naming the computed analysis-revenue series. When passed as
  # the `field:` of weekly_totals_for / daily_rolling_revenue_for, the helper
  # plucks both gross_sales and ticketing_fees and computes revenue_on per row.
  #
  # Analysis revenue = all payments (incl. third-party) net of ticketing fees,
  # gross of processing fees — same treatment as RoyaltyReport. Rows not yet
  # backfilled have nil ticketing_fees and fall back to gross. (Fix 3)
  REVENUE_FIELD = :revenue

  # Fix 5 (momentum model — tunable). Daily-rolling-based weekly rate, clamped
  # and decayed each projected week so momentum fades toward flat rather than
  # compounding blindly over a short (4-7 week) run. Tune these freely.
  MOMENTUM_CLAMP_PCT = 15.0 # max |weekly rate| applied, in percent
  MOMENTUM_DECAY = 0.5      # applied rate is halved each successive projected week

  def initialize(target_production, comparison_productions)
    @target_production = target_production
    @comparison_productions = comparison_productions
  end

  def compute(extra_weeks: 0)
    cutoff = Date.today.beginning_of_week
    target_tickets = weekly_pct_change_for(target_production, cutoff: cutoff)
    target_revenue = weekly_pct_change_for(target_production, cutoff: cutoff, field: REVENUE_FIELD)
    comparison_series = comparison_productions.map { |p| weekly_pct_change_for(p) }
    aggregate_data = aggregate_series(comparison_series)
    # Fix 2: parallel aggregate built from the REVENUE pct series, so target
    # revenue is compared against aggregate revenue (not aggregate tickets).
    comparison_revenue_series = comparison_productions.map { |p| weekly_pct_change_for(p, field: REVENUE_FIELD) }
    aggregate_revenue_data = aggregate_series(comparison_revenue_series)
    projection = compute_projection(cutoff, extra_weeks: extra_weeks)

    comparison_summaries = comparison_productions.map do |p|
      weekly = weekly_totals_for(p, field: REVENUE_FIELD)
      total_revenue = weekly.values.sum
      num_weeks = extract_max_week(weekly)
      { production: p, total_revenue: total_revenue, num_weeks: num_weeks }
    end

    target_weekly_rev = weekly_totals_for(target_production, cutoff: cutoff, field: REVENUE_FIELD)
    target_summary = {
      production: target_production,
      total_revenue: target_weekly_rev.values.sum,
      num_weeks: extract_max_week(target_weekly_rev)
    }

    daily_rolling = daily_rolling_revenue_for(target_production, cutoff: Date.yesterday)
    comparison_daily_rolling = if comparison_productions.size == 1
                                 daily_rolling_revenue_for(comparison_productions.first, cutoff: Date.today)
                               end
    insights = compute_insights(cutoff, target_tickets, target_revenue, aggregate_data, aggregate_revenue_data,
                                daily_rolling)

    { target_tickets: target_tickets, target_revenue: target_revenue, aggregate_data: aggregate_data,
      aggregate_revenue_data: aggregate_revenue_data,
      projection: projection, comparison_summaries: comparison_summaries, target_summary: target_summary, insights: insights, daily_rolling: daily_rolling, comparison_daily_rolling: comparison_daily_rolling }
  end

  private

  def compute_projection(cutoff, extra_weeks: 0)
    return nil if target_production.closing_at.nil?

    anchor = target_production.first_playing_date
    presale_cutoff = anchor - 21.days

    baseline_total_weeks = ((target_production.closing_at - presale_cutoff).to_i / 7) + 1
    total_weeks = baseline_total_weeks + extra_weeks

    # Target's actual weekly revenue (through cutoff)
    target_weekly = weekly_totals_for(target_production, cutoff: cutoff, field: REVENUE_FIELD)
    return nil if target_weekly.empty?

    last_actual_week = extract_max_week(target_weekly)

    # Fix 1: the actual buckets anchor on presale_cutoff (rarely a Monday) but
    # actuals are cut at the start-of-week `cutoff`, so the final actual bucket
    # is usually partial. A partial final bucket must NOT drive the ratio or the
    # momentum window (its revenue still counts in the cumulative totals — it's
    # real money). last_complete_week is the newest bucket whose 7-day span ends
    # on/before the cutoff.
    last_complete_week = last_complete_week_num(presale_cutoff, cutoff, last_actual_week)

    # Nothing to project if the show is already over
    return nil if last_actual_week >= total_weeks

    # Aggregate average weekly revenue (raw $, full runs) across comparison productions.
    # Pre-sales is intentionally NOT part of the expectation curve (presale
    # periods vary too much between productions). (Fix 4)
    comparison_weekly = comparison_productions.map { |p| weekly_totals_for(p, field: REVENUE_FIELD) }
    aggregate_weekly_avg = average_weekly_totals(comparison_weekly)
    return nil if aggregate_weekly_avg.empty?

    # Fix 1: ratio is computed over COMPLETE actual weeks only (the partial
    # final bucket carries decay^0 weight and would contaminate the result).
    complete_target_weekly = target_weekly.reject do |label, _|
      label =~ /^Week (\d+)$/ && ::Regexp.last_match(1).to_i > last_complete_week
    end
    ratio = weighted_performance_ratio(complete_target_weekly, aggregate_weekly_avg)
    return nil if ratio.nil? || ratio <= 0

    # Build actual cumulative revenue (includes the partial final bucket).
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

    # Fix 4: build the expectation against MATCHING weeks (weeks are already
    # opening-aligned), end-aligning the comparisons' decline tail to the
    # target's closing week. expected_weekly_value(week_num) handles the mapping.
    hist_body, hist_tail = historical_body_and_tail(aggregate_weekly_avg)

    # Fix 1: if the final actual bucket is partial, project its remaining days
    # as the first projected increment (expected week value * ratio, pro-rated
    # by remaining_days/7). Otherwise projection starts at last_actual_week + 1.
    partial_remaining_days = partial_bucket_remaining_days(presale_cutoff, cutoff, last_actual_week,
                                                           last_complete_week)

    projected_cumulative = {}
    projected_remaining = 0.0
    remaining_budget = remaining_rev_budget_initial
    capacity_clipped = false

    # Pro-rate the partial week's remaining days into the existing partial bucket.
    if partial_remaining_days.positive?
      expected = expected_weekly_value(last_actual_week, total_weeks, hist_body, hist_tail)
      projected_week = expected * ratio * (partial_remaining_days / 7.0)
      if projected_week > remaining_budget
        projected_week = [remaining_budget, 0.0].max
        capacity_clipped = true
      end
      projected_week = projected_week.round(2)
      remaining_budget -= projected_week
      projected_remaining += projected_week
      running_total += projected_week
      projected_cumulative["Week #{last_actual_week}"] = running_total.round(2)
    end

    (last_actual_week + 1..total_weeks).each do |week_num|
      key = "Week #{week_num}"
      expected = expected_weekly_value(week_num, total_weeks, hist_body, hist_tail)
      projected_week = expected * ratio
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

    alternate = compute_alternate_projection(
      target_weekly: target_weekly,
      last_actual_week: last_actual_week,
      last_complete_week: last_complete_week,
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

  # Fix 4: expected revenue for target week N.
  #   - The target's final `tail.size` weeks use the (end-aligned) decline tail,
  #     because closing-week dynamics belong at the close.
  #   - Earlier weeks use the matching "Week N" body value.
  #   - If the target runs longer than the comparisons (incl. extra_weeks),
  #     weeks between the last matching body week and the end-aligned tail are
  #     filled with the plateau level (avg of the last 2 body weeks).
  def expected_weekly_value(week_num, total_weeks, body, tail)
    tail_size = tail.size
    tail_start_week = total_weeks - tail_size + 1 # first week occupied by the end-aligned tail

    if tail_size.positive? && week_num >= tail_start_week
      tail_idx = week_num - tail_start_week
      return tail[tail_idx]
    end

    # Body region (everything before the end-aligned tail).
    if week_num <= body.size
      body[week_num - 1]
    else
      # Gap between the last matching body week and the end-aligned tail:
      # hold the plateau level. extra_weeks widens this gap.
      plateau_level(body)
    end
  end

  # Plateau level = average of the last two body weeks (or the single value).
  def plateau_level(body)
    return 0.0 if body.empty?
    return body.last if body.size == 1

    (body[-1] + body[-2]) / 2.0
  end

  # Build the opening-aligned aggregate revenue curve and split into body
  # (growth + plateau) and decline tail. split_curve_at_decline still FINDS the
  # tail; we no longer stretch either piece. (Fix 4)
  def historical_body_and_tail(aggregate_weekly_avg)
    week_pairs = aggregate_weekly_avg.select { |k, _| k =~ /^Week \d+$/ }
    # Fix 4: Pre-sales must NEVER enter the expectation curve — presale periods
    # vary too much between productions to be comparable. The /^Week \d+$/ filter
    # above already excludes it; assert it explicitly so a future change to the
    # label scheme can't silently let pre-sales leak into the projection.
    raise 'Pre-sales must not enter the expectation curve' if week_pairs.key?('Pre-sales')

    hist_curve = week_pairs.sort_by { |k, _| k[/\d+/].to_i }
                           .map(&:last)
    # Drop trailing partial/straggler weeks (near-zero revenue after show closes)
    peak_val = hist_curve.max || 0
    hist_curve.pop while hist_curve.size > 1 && hist_curve.last < peak_val * 0.01

    split_curve_at_decline(hist_curve)
  end

  # Fix 1 helper: the newest COMPLETE actual week. Bucket N spans
  # [presale_cutoff + (N-1)*7, presale_cutoff + N*7); it is complete iff its end
  # (presale_cutoff + N*7) <= cutoff. Returns 0 if no week is complete.
  def last_complete_week_num(presale_cutoff, cutoff, last_actual_week)
    complete = 0
    (1..last_actual_week).each do |n|
      bucket_end = presale_cutoff + (n * 7).days
      complete = n if bucket_end <= cutoff
    end
    complete
  end

  # Fix 1 helper: number of days still unplayed in the partial final bucket.
  # Zero when the final bucket is already complete (or there's no bucket).
  def partial_bucket_remaining_days(presale_cutoff, cutoff, last_actual_week, last_complete_week)
    return 0 if last_actual_week.zero? || last_complete_week >= last_actual_week

    bucket_start = presale_cutoff + ((last_actual_week - 1) * 7).days
    elapsed = (cutoff - bucket_start).to_i
    remaining = 7 - elapsed
    remaining.clamp(0, 7)
  end

  # Alternate projection (Fix 5 — pure momentum). Anchor on the target's recent
  # 7-day rolling revenue and apply a decaying weekly rate forward. No
  # historical-show scaling — the projection reflects the current show's
  # observed trajectory, capped by remaining seat inventory.
  def compute_alternate_projection(target_weekly:, last_actual_week:, last_complete_week:, total_weeks:,
                                   actual_total:, remaining_rev_budget_initial:)
    # Anchor on the 7-day rolling revenue (more stable than the partial final
    # weekly bucket).
    daily_rolling = daily_rolling_revenue_for(target_production, cutoff: Date.yesterday)
    anchor_weekly = daily_rolling.values.last.to_f
    if anchor_weekly <= 0
      # Fall back to the last COMPLETE weekly bucket, not the partial one. (Fix 1)
      fallback_week = last_complete_week.positive? ? last_complete_week : last_actual_week
      anchor_weekly = target_weekly["Week #{fallback_week}"].to_f
    end

    # Fix 5: weekly rate derived from the daily-rolling trajectory (last 7
    # complete days vs the prior 7), reusing compute_insights #4's pattern.
    momentum_raw_pct, momentum_window = compute_momentum(daily_rolling)
    # Clamp so a single early-run spike can't drive runaway growth/decay.
    momentum_pct_clamped = momentum_raw_pct.clamp(-MOMENTUM_CLAMP_PCT, MOMENTUM_CLAMP_PCT)

    alt_cumulative = {}
    alt_remaining = 0.0
    cum = actual_total
    prev_weekly = anchor_weekly
    remaining_budget = remaining_rev_budget_initial
    capacity_clipped = false

    (last_actual_week + 1..total_weeks).each_with_index do |_week_num, step|
      key = "Week #{_week_num}"
      # Fix 5: decay the applied rate by half each successive projected week so
      # momentum fades toward flat instead of compounding indefinitely.
      decayed_rate = momentum_pct_clamped * (MOMENTUM_DECAY**step)
      weekly = prev_weekly * (1 + (decayed_rate / 100.0))
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
      alternate_momentum_raw_pct: momentum_raw_pct.round(1),
      alternate_momentum_window: momentum_window,
      alternate_anchor: anchor_weekly.round(2),
      alternate_initial_budget: remaining_rev_budget_initial.finite? ? remaining_rev_budget_initial.round(2) : nil,
      capacity_clipped: capacity_clipped
    }
  end

  # Returns [weekly_rate_pct, window_size]. (Fix 5)
  #
  # Daily-rolling-based momentum: average of the last 7 complete days' rolling
  # revenue vs the prior 7 days, expressed as a pct (same trajectory pattern as
  # compute_insights #4). This replaces the former median-of-last-3-weekly-pct
  # model — daily rolling is steadier on short runs and isn't biased by the
  # partial final weekly bucket. window_size reports the number of rolling
  # points used (14 when a full two-window comparison is available).
  #
  # Returns [0.0, 0] when there isn't enough daily history (< 14 points) or the
  # prior window is non-positive.
  def compute_momentum(daily_rolling)
    values = daily_rolling.values
    return [0.0, 0] if values.size < 14

    recent_avg = values.last(7).sum / 7.0
    prior_avg  = values[-14..-8].sum / 7.0
    return [0.0, values.size] if prior_avg <= 0

    rate = (recent_avg - prior_avg) / prior_avg * 100.0
    [rate, values.size]
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

  def compute_insights(cutoff, target_tickets_pct, target_revenue_pct, aggregate_pct, aggregate_revenue_pct,
                       daily_rolling)
    insights = {}

    # Raw weekly totals for the current show
    target_ticket_totals = weekly_totals_for(target_production, cutoff: cutoff)
    target_revenue_totals = weekly_totals_for(target_production, cutoff: cutoff, field: REVENUE_FIELD)

    # Aggregate raw weekly totals across comparison productions
    comp_ticket_series = comparison_productions.map { |p| weekly_totals_for(p) }
    comp_revenue_series = comparison_productions.map { |p| weekly_totals_for(p, field: REVENUE_FIELD) }
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

    # 2. Ticket growth comparison — tickets-vs-tickets, last 3 weeks only to
    # avoid early spikes (e.g., 500% from near-zero) dominating the average.
    overlapping_pct = (target_tickets_pct.keys & aggregate_pct.keys) - ['Pre-sales']
    compare_keys = overlapping_pct.sort_by { |k| k[/\d+/].to_i }.last(3)
    if compare_keys.size >= 2
      target_avg_pct = compare_keys.sum { |k| target_tickets_pct[k] } / compare_keys.size.to_f
      hist_avg_pct = compare_keys.sum { |k| aggregate_pct[k] } / compare_keys.size.to_f
      insights[:ticket_growth_avg] = target_avg_pct.round(1)
      insights[:hist_ticket_growth_avg] = hist_avg_pct.round(1)
      insights[:ticket_growth_diff] = (target_avg_pct - hist_avg_pct).round(1)
      insights[:growth_window] = compare_keys.size
    end

    # 3. Revenue growth comparison — revenue-vs-revenue. (Fix 2: the historical
    # side now comes from aggregate_revenue_pct, NOT the ticket aggregate.)
    overlapping_rev = (target_revenue_pct.keys & aggregate_revenue_pct.keys) - ['Pre-sales']
    rev_compare_keys = overlapping_rev.sort_by { |k| k[/\d+/].to_i }.last(3)
    if rev_compare_keys.size >= 2
      target_rev_avg_pct = rev_compare_keys.sum { |k| target_revenue_pct[k] } / rev_compare_keys.size.to_f
      hist_rev_avg_pct = rev_compare_keys.sum { |k| aggregate_revenue_pct[k] } / rev_compare_keys.size.to_f
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
      insights[:performance_pct] =
        ((insights[:avg_revenue_per_week] / insights[:hist_avg_revenue_per_week]) * 100).round(0)
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
    weekly_data.keys.grep(/^Week (\d+)$/) { ::Regexp.last_match(1).to_i }.max || 0
  end

  # Averages raw weekly totals across multiple productions by week label.
  # Zero-valued weeks are EXCLUDED from the average: shows don't have dead weeks,
  # so a missing/zero week means the show wasn't on sale that week (not zero
  # demand), and averaging zeros in would understate the curve. (Fix 4)
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

  # Exponentially-weighted ratio of target vs aggregate weekly revenue.
  # Recent weeks weighted more heavily (decay factor 0.7). Pre-sales is skipped
  # (collapsed bucket; presale periods vary too much to compare). The caller is
  # responsible for excluding any incomplete final bucket before calling. (Fix 1)
  def weighted_performance_ratio(target_weekly, aggregate_weekly)
    decay = 0.7
    overlapping = []

    target_weekly.each do |label, target_val|
      next if label == 'Pre-sales' # skip pre-sales for ratio since it's a collapsed bucket

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

  # Returns a hash of { "M/D/YY" => rolling_7day_sum } for the production's daily
  # analysis-revenue (revenue_on per row). (Fix 3)
  def daily_rolling_revenue_for(production, cutoff:)
    anchor = production.first_playing_date
    presale_cutoff = anchor - 21.days

    records = production.rate_of_sales
                        .where('day_of_sale <= ?', cutoff)
                        .pluck(:day_of_sale, :gross_sales, :ticketing_fees)

    return {} if records.empty?

    daily_sales = records.each_with_object({}) do |(day, gross, tfees), h|
      h[day] = revenue_value(gross, tfees)
    end

    start_date = presale_cutoff
    last_sale = records.map(&:first).max
    end_date = [cutoff, last_sale].min

    result = {}
    (start_date..end_date).each do |date|
      rolling_sum = (0..6).sum { |i| daily_sales[date - i.days] || 0.0 }
      result[date.strftime('%-m/%-d/%y')] = rolling_sum.round(2)
    end

    result
  end

  # Returns a hash of { "Pre-sales" => pct, "Week 1" => pct, ... }
  # representing % change week over week for the given field.
  def weekly_pct_change_for(production, cutoff: nil, field: :total_single_tickets)
    weekly_totals = weekly_totals_for(production, cutoff: cutoff, field: field)
    compute_pct_changes(weekly_totals)
  end

  # Returns an ordered hash of { week_label => total } for the given field.
  # When field == REVENUE_FIELD the value per row is the computed analysis
  # revenue (revenue_on); otherwise it's the raw column (e.g. tickets). (Fix 3)
  def weekly_totals_for(production, cutoff: nil, field: :total_single_tickets)
    anchor = production.first_playing_date
    presale_cutoff = anchor - 21.days

    scope = production.rate_of_sales.order(:day_of_sale)
    scope = scope.where('day_of_sale < ?', cutoff) if cutoff

    rows = field == REVENUE_FIELD ? scope.pluck(:day_of_sale, :gross_sales, :ticketing_fees) : scope.pluck(:day_of_sale, field)
    return {} if rows.empty?

    buckets = Hash.new(0.0)

    rows.each do |row|
      day = row.first
      value = field == REVENUE_FIELD ? revenue_value(row[1], row[2]) : row[1].to_f

      if day < presale_cutoff
        buckets['Pre-sales'] += value
      else
        week_num = ((day - presale_cutoff).to_i / 7) + 1
        buckets["Week #{week_num}"] += value
      end
    end

    # Return in order: Pre-sales first, then Week 1, 2, 3...
    ordered = ActiveSupport::OrderedHash.new
    ordered['Pre-sales'] = buckets['Pre-sales'] if buckets.key?('Pre-sales')
    max_week = buckets.keys.grep(/^Week (\d+)$/) { ::Regexp.last_match(1).to_i }.max || 0
    (1..max_week).each do |n|
      key = "Week #{n}"
      ordered[key] = buckets[key] if buckets.key?(key)
    end

    ordered
  end

  # Analysis revenue for a single row: gross_sales net of ticketing fees, gross
  # of processing fees — same treatment as RoyaltyReport. Rows not yet
  # backfilled have nil ticketing_fees and fall back to gross. (Fix 3)
  def revenue_value(gross_sales, ticketing_fees)
    gross_sales.to_f - ticketing_fees.to_f
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
      remaining = curve[i..]
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
      tail = curve[decline_start..]
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

  def sort_week_labels(labels)
    labels.sort_by do |label|
      if label == 'Pre-sales'
        -1
      elsif label =~ /^Week (\d+)$/
        ::Regexp.last_match(1).to_i
      else
        999
      end
    end
  end
end
