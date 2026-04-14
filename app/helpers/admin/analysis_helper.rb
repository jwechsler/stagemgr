module Admin::AnalysisHelper
  BUCKET_PALETTE = %w[
    #1779ba #3adb76 #ffae00 #cc4b37 #5e4b8b
    #00b9c8 #8b4b8b #4b8b5e #8b8b00 #8b4b00
  ].freeze
  COMP_COLOR     = '#e8a838'
  ZERO_REV_COLOR = '#a0aab4'
  UNSOLD_COLOR   = '#d6d6d6'

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

  # Returns the subtitle portion of a bucket label.
  def bucket_subtitle(bucket)
    return 'Comp'       if bucket.bucket_type == :comp
    return 'No Revenue' if bucket.bucket_type == :zero_rev
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
    total_cap       = summary.total_capacity.to_f
    total_paid      = summary.total_paid.to_f
    zero_rev_count  = summary.buckets.select { |b| b.bucket_type == :zero_rev }.sum(&:paid_count)

    # Assign palette colors to non-special buckets in stable order
    palette_idx = -1
    bucket_colors = summary.buckets.each_with_object({}) do |bucket, h|
      h[bucket.object_id] = case bucket.bucket_type
                            when :comp     then COMP_COLOR
                            when :zero_rev then ZERO_REV_COLOR
                            else
                              palette_idx += 1
                              BUCKET_PALETTE[palette_idx % BUCKET_PALETTE.size]
                            end
    end

    # Capacity mode: all buckets + Unsold
    issued       = summary.total_paid + summary.comp_count + zero_rev_count
    unsold_count = [summary.total_capacity - issued, 0].max
    unsold_pct   = total_cap > 0 ? (unsold_count.to_f / total_cap * 100).round(2) : 0

    cap_labels  = summary.buckets.map { |b| bucket_label(b) } + ['Unsold']
    cap_values  = summary.buckets.map { |b|
      total_cap > 0 ? (b.paid_count.to_f / total_cap * 100).round(2) : 0
    } + [unsold_pct]
    cap_colors  = summary.buckets.map { |b| bucket_colors[b.object_id] } + [UNSOLD_COLOR]
    cap_ladders = summary.buckets.map(&:ladder_distribution) + [{}]

    # Paid mode: only dynamic + singleton buckets, normalized to paid total
    paid_buckets = summary.buckets.select { |b| [:dynamic, :singleton].include?(b.bucket_type) }
    paid_labels  = paid_buckets.map { |b| bucket_label(b) }
    paid_values  = paid_buckets.map { |b|
      total_paid > 0 ? (b.paid_count.to_f / total_paid * 100).round(2) : 0
    }
    paid_colors  = paid_buckets.map { |b| bucket_colors[b.object_id] }
    paid_ladders = paid_buckets.map(&:ladder_distribution)

    {
      capacity: { labels: cap_labels,  values: cap_values,  colors: cap_colors,  ladders: cap_ladders },
      paid:     { labels: paid_labels, values: paid_values, colors: paid_colors, ladders: paid_ladders }
    }
  end

  def bucket_label(bucket)
    flag = bucket.allocation_cap_hit ? " \u2691" : ''
    return "#{bucket.name}#{flag}" if [:comp, :zero_rev].include?(bucket.bucket_type)
    price_dollar = bucket.avg_paid_price.round
    prefix = bucket.bucket_type == :dynamic ? "\u21C5 " : ''
    suffix = bucket.bucket_type == :dynamic ? ' avg' : ''
    "#{prefix}$#{price_dollar}#{suffix}#{flag}\n(#{bucket_subtitle(bucket)})"
  end
end
