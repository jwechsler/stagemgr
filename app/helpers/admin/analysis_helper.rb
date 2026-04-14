module Admin::AnalysisHelper
  BUCKET_PALETTE = %w[
    #1779ba #3adb76 #ffae00 #cc4b37 #5e4b8b
    #00b9c8 #8b4b8b #4b8b5e #8b8b00 #8b4b00
  ].freeze
  COMP_COLOR   = '#e8a838'
  UNSOLD_COLOR = '#d6d6d6'

  # Returns the longest common leading substring shared by all strings in the array.
  def common_prefix_of(strings)
    return '' if strings.empty?
    strs = strings.map(&:to_s)
    return strs.first if strs.size == 1
    sorted_first = strs.min
    sorted_last  = strs.max
    i = 0
    i += 1 while i < sorted_first.length && sorted_first[i] == sorted_last[i]
    sorted_first[0...i]
  end

  # Returns the subtitle portion of a bucket label:
  # - common prefix of class codes if one exists (e.g. "GEN" from GEN36/GEN40/GEN44)
  # - falls back to price range string if no common prefix
  def bucket_subtitle(bucket)
    prefix = common_prefix_of(bucket.class_codes).sub(/\d+$/, '')
    if prefix.length >= 1
      prefix
    elsif bucket.price_min == bucket.price_max
      "$#{bucket.price_min.to_i}"
    else
      "$#{bucket.price_min.to_i}\u2013$#{bucket.price_max.to_i}"
    end
  end

  # Returns a hash consumed by ticket_revenue.html.haml's Chart.js block:
  # {
  #   capacity: { labels: [], values: [], colors: [], ladders: [] },
  #   paid:     { labels: [], values: [], colors: [], ladders: [] }
  # }
  # Each array is parallel-indexed (labels[i], values[i], colors[i], ladders[i] all describe bar i).
  def bucket_chart_data(summary)
    total_cap  = summary.total_capacity.to_f
    total_paid = summary.total_paid.to_f

    bucket_labels = summary.buckets.each_with_index.map do |bucket, _i|
      avg_dollar = bucket.avg_paid_price.round
      flag       = bucket.allocation_cap_hit ? " \u2691" : ''
      "$#{avg_dollar} avg#{flag}\n(#{bucket_subtitle(bucket)})"
    end

    bucket_colors  = summary.buckets.each_with_index.map { |_, i| BUCKET_PALETTE[i % BUCKET_PALETTE.size] }
    bucket_ladders = summary.buckets.map(&:ladder_distribution)

    # Capacity mode: paid buckets + Comp + Unsold
    unsold_count = [summary.total_capacity - summary.total_paid - summary.comp_count, 0].max
    comp_pct     = total_cap > 0 ? (summary.comp_count.to_f  / total_cap * 100).round(2) : 0
    unsold_pct   = total_cap > 0 ? (unsold_count.to_f        / total_cap * 100).round(2) : 0

    cap_values = summary.buckets.map { |b|
      total_cap > 0 ? (b.paid_count.to_f / total_cap * 100).round(2) : 0
    } + [comp_pct, unsold_pct]

    cap_labels  = bucket_labels + ['Comp', 'Unsold']
    cap_colors  = bucket_colors + [COMP_COLOR, UNSOLD_COLOR]
    cap_ladders = bucket_ladders + [{}, {}]

    # Paid-only mode: paid buckets only, normalized to 100%
    paid_values = summary.buckets.map { |b|
      total_paid > 0 ? (b.paid_count.to_f / total_paid * 100).round(2) : 0
    }

    {
      capacity: { labels: cap_labels,    values: cap_values,  colors: cap_colors,  ladders: cap_ladders },
      paid:     { labels: bucket_labels, values: paid_values, colors: bucket_colors, ladders: bucket_ladders }
    }
  end
end
