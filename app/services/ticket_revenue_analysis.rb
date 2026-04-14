class TicketRevenueAnalysis
  BucketResult = Struct.new(
    :name, :ticket_class_ids, :class_codes, :entry_price,
    :paid_count, :avg_paid_price, :price_min, :price_max,
    :ladder_distribution, :actual_gross,
    :flat_base_gross, :dynamic_lift_dollars, :dynamic_lift_pct,
    :bucket_allocation, :allocation_from_limit, :sell_through_pct, :allocation_cap_hit,
    keyword_init: true
  )

  Summary = Struct.new(
    :production, :buckets, :comp_count, :total_capacity,
    :total_paid, :capacity_utilization_pct, :gross_revenue,
    :overall_avg_paid_price, :total_dynamic_lift_dollars, :total_dynamic_lift_pct,
    :performance_count, :completed_performance_count,
    keyword_init: true
  )

  def initialize(production)
    @production = production
  end

  def compute
    Rails.cache.fetch(cache_key, expires_in: 1.hour) { uncached_compute }
  end

  private

  def cache_key
    "ticket_revenue_analysis/#{@production.id}/v1/#{@production.updated_at.to_i}"
  end

  def uncached_compute
    ticket_classes  = @production.ticket_classes.to_a
    perf_count      = @production.performances.count
    completed_perfs = @production.performances.where("performance_date < ?", Date.today).count

    return empty_summary(perf_count, completed_perfs) if ticket_classes.empty?

    class_by_code = ticket_classes.index_by(&:class_code)
    class_by_id   = ticket_classes.index_by(&:id)
    comp_tc_ids   = ticket_classes.select(&:complimentary?).map(&:id).to_set

    edges           = build_promotion_edges(class_by_code)
    buckets         = union_find_buckets(ticket_classes.map(&:id), edges)
    entry_prices    = entry_prices_for_buckets(buckets, edges, class_by_id)
    line_items      = fetch_line_items
    allocation_data = fetch_allocation_data
    fallback_alloc  = (@production.capacity || 0) * perf_count

    comp_count = [
      line_items.select { |r| comp_tc_ids.include?(r[:tc_id]) }.sum { |r| r[:count] },
      0
    ].max

    bucket_results = buckets.each_with_index.map do |tc_ids, i|
      paid_rows = line_items.select { |r|
        tc_ids.include?(r[:tc_id]) && !comp_tc_ids.include?(r[:tc_id])
      }
      build_bucket(
        tc_ids:              tc_ids,
        class_by_id:         class_by_id,
        entry_price:         entry_prices[i],
        paid_rows:           paid_rows,
        allocation_data:     allocation_data,
        fallback_allocation: fallback_alloc
      )
    end.compact.sort_by { |b| -(b.avg_paid_price || 0) }

    bucket_results = merge_same_price_buckets(bucket_results)

    total_paid    = bucket_results.sum(&:paid_count)
    total_cap     = (@production.capacity || 0) * perf_count
    gross_revenue = bucket_results.sum(&:actual_gross)
    overall_avg   = total_paid > 0 ? gross_revenue / total_paid : BigDecimal('0')

    dynamic_buckets = bucket_results.select { |b| b.ticket_class_ids.size > 1 }
    total_lift      = dynamic_buckets.sum(&:dynamic_lift_dollars)
    total_flat_base = dynamic_buckets.sum(&:flat_base_gross)
    total_lift_pct  = total_flat_base > 0 ? (total_lift / total_flat_base * 100).round(2) : nil
    cap_util        = total_cap > 0 ? ((total_paid + comp_count).to_f / total_cap * 100).round(1) : 0

    Summary.new(
      production:                  @production,
      buckets:                     bucket_results,
      comp_count:                  comp_count,
      total_capacity:              total_cap,
      total_paid:                  total_paid,
      capacity_utilization_pct:    cap_util,
      gross_revenue:               gross_revenue,
      overall_avg_paid_price:      overall_avg,
      total_dynamic_lift_dollars:  total_lift,
      total_dynamic_lift_pct:      total_lift_pct,
      performance_count:           perf_count,
      completed_performance_count: completed_perfs
    )
  end

  def build_promotion_edges(class_by_code)
    TicketClassAllocation
      .joins("INNER JOIN performances ON performances.id = ticket_class_allocations.performance_id")
      .where("performances.production_id = ?", @production.id)
      .where(shiftable: true)
      .where.not(shift_to_code: nil)
      .pluck("ticket_class_allocations.ticket_class_id", "ticket_class_allocations.shift_to_code")
      .filter_map do |from_id, to_code|
        to_tc = class_by_code[to_code]
        to_tc && to_tc.id != from_id ? [from_id, to_tc.id] : nil
      end
      .uniq
  end

  def union_find_buckets(all_ids, edges)
    parent = all_ids.each_with_object({}) { |id, h| h[id] = id }

    find = lambda { |x|
      parent[x] = find.call(parent[x]) unless parent[x] == x
      parent[x]
    }

    edges.each { |a, b| parent[find.call(a)] = find.call(b) }

    all_ids.group_by { |id| find.call(id) }.values
  end

  def entry_prices_for_buckets(buckets, edges, class_by_id)
    ids_with_incoming = edges.map { |_from, to| to }.to_set

    buckets.map do |tc_ids|
      entry_tcs = tc_ids
                    .reject { |id| ids_with_incoming.include?(id) }
                    .map    { |id| class_by_id[id] }
                    .compact

      entry_tc = entry_tcs.min_by { |tc| effective_class_price(tc) }
      if entry_tc
        effective_class_price(entry_tc)
      else
        tc_ids.map { |id| class_by_id[id] }.compact
              .map { |tc| effective_class_price(tc) }
              .min || BigDecimal('0')
      end
    end
  end

  def effective_class_price(ticket_class)
    if ticket_class.ticket_price == 0 && ticket_class.royalty_amount
      ticket_class.royalty_amount
    else
      ticket_class.ticket_price
    end
  end

  def fetch_line_items
    TicketLineItem
      .joins("INNER JOIN orders ON orders.id = line_items.order_id")
      .joins("INNER JOIN performances ON performances.id = orders.performance_id")
      .joins("INNER JOIN ticket_classes tc ON tc.id = line_items.ticket_class_id")
      .where("performances.production_id = ?", @production.id)
      .where("orders.status IN (?)", Order::FINALIZED_STATUSES)
      .pluck(
        "line_items.ticket_class_id",
        "line_items.ticket_count",
        "line_items.price_override",
        "tc.ticket_price",
        "tc.royalty_amount",
        "tc.complimentary"
      )
      .map do |tc_id, count, override, price, royalty, comp|
        {
          tc_id:    tc_id,
          count:    count.to_i,
          override: override ? BigDecimal(override.to_s) : nil,
          price:    BigDecimal(price.to_s),
          royalty:  royalty ? BigDecimal(royalty.to_s) : nil,
          comp:     comp == 1 || comp == true
        }
      end
  end

  def fetch_allocation_data
    rows = TicketClassAllocation
             .joins("INNER JOIN performances ON performances.id = ticket_class_allocations.performance_id")
             .where("performances.production_id = ?", @production.id)
             .pluck(
               "ticket_class_allocations.ticket_class_id",
               "ticket_class_allocations.ticket_limit"
             )

    rows.group_by { |tc_id, _| tc_id }.each_with_object({}) do |(tc_id, pairs), h|
      limits = pairs.map { |_, limit| limit }.compact
      h[tc_id] = {
        total_limit:   limits.any? ? limits.sum : nil,
        has_any_limit: limits.any?
      }
    end
  end

  def effective_price(row)
    return nil if row[:comp]
    if row[:price] == 0 && row[:royalty]
      row[:royalty]
    elsif row[:override]
      row[:override]
    else
      row[:price]
    end
  end

  def build_bucket(tc_ids:, class_by_id:, entry_price:, paid_rows:, allocation_data:, fallback_allocation:)
    priced_rows = paid_rows.filter_map do |r|
      ep = effective_price(r)
      ep ? { count: r[:count], price: ep } : nil
    end

    total_count = priced_rows.sum { |r| r[:count] }
    return nil if total_count <= 0

    weighted_sum = priced_rows.sum { |r| r[:price] * r[:count] }
    avg_price    = weighted_sum / total_count
    price_min    = priced_rows.map { |r| r[:price] }.min
    price_max    = priced_rows.map { |r| r[:price] }.max

    ladder = priced_rows.each_with_object(Hash.new(0)) do |r, h|
      h[r[:price].to_f.round(2)] += r[:count]
    end

    bucket_alloc = 0
    from_limit   = false
    tc_ids.each do |tc_id|
      data = allocation_data[tc_id]
      next unless data
      if data[:has_any_limit] && data[:total_limit].to_i > 0
        bucket_alloc += data[:total_limit].to_i
        from_limit = true
      end
    end
    bucket_alloc = fallback_allocation unless from_limit && bucket_alloc > 0

    sell_through   = bucket_alloc > 0 ? (total_count.to_f / bucket_alloc * 100).round(1) : nil
    cap_hit        = from_limit && bucket_alloc > 0 && total_count >= bucket_alloc
    flat_base      = entry_price * total_count
    lift_dollars   = weighted_sum - flat_base
    lift_pct       = flat_base > 0 ? (lift_dollars / flat_base * 100).round(2) : nil
    class_codes    = tc_ids.map { |id| class_by_id[id]&.class_code }.compact

    BucketResult.new(
      name:                  class_codes.join("/"),
      ticket_class_ids:      tc_ids,
      class_codes:           class_codes,
      entry_price:           entry_price,
      paid_count:            total_count,
      avg_paid_price:        avg_price,
      price_min:             price_min,
      price_max:             price_max,
      ladder_distribution:   ladder,
      actual_gross:          weighted_sum,
      flat_base_gross:       flat_base,
      dynamic_lift_dollars:  lift_dollars,
      dynamic_lift_pct:      lift_pct,
      bucket_allocation:     bucket_alloc,
      allocation_from_limit: from_limit,
      sell_through_pct:      sell_through,
      allocation_cap_hit:    cap_hit
    )
  end

  def merge_same_price_buckets(sorted_buckets)
    sorted_buckets
      .group_by { |b| b.avg_paid_price.round }
      .values
      .map { |group| group.size == 1 ? group.first : merge_bucket_group(group) }
      .sort_by { |b| -(b.avg_paid_price || 0) }
  end

  def merge_bucket_group(group)
    total_count  = group.sum(&:paid_count)
    total_gross  = group.sum(&:actual_gross)
    total_flat   = group.sum(&:flat_base_gross)
    avg_price    = total_count > 0 ? total_gross / total_count : BigDecimal('0')
    lift_dollars = total_gross - total_flat
    flat_base    = total_flat
    lift_pct     = flat_base > 0 ? (lift_dollars / flat_base * 100).round(2) : nil

    merged_ladder = group.each_with_object(Hash.new(0)) do |b, h|
      b.ladder_distribution.each { |price, count| h[price] += count }
    end

    all_prices     = group.flat_map { |b| [b.price_min, b.price_max] }.compact
    total_alloc    = group.sum(&:bucket_allocation)
    from_limit     = group.any?(&:allocation_from_limit)
    sell_through   = total_alloc > 0 ? (total_count.to_f / total_alloc * 100).round(1) : nil
    cap_hit        = group.any?(&:allocation_cap_hit)

    BucketResult.new(
      name:                  group.map(&:name).join("/"),
      ticket_class_ids:      group.flat_map(&:ticket_class_ids),
      class_codes:           group.flat_map(&:class_codes),
      entry_price:           group.map(&:entry_price).min,
      paid_count:            total_count,
      avg_paid_price:        avg_price,
      price_min:             all_prices.min,
      price_max:             all_prices.max,
      ladder_distribution:   merged_ladder,
      actual_gross:          total_gross,
      flat_base_gross:       flat_base,
      dynamic_lift_dollars:  lift_dollars,
      dynamic_lift_pct:      lift_pct,
      bucket_allocation:     total_alloc,
      allocation_from_limit: from_limit,
      sell_through_pct:      sell_through,
      allocation_cap_hit:    cap_hit
    )
  end

  def empty_summary(perf_count, completed_perfs)
    Summary.new(
      production:                  @production,
      buckets:                     [],
      comp_count:                  0,
      total_capacity:              0,
      total_paid:                  0,
      capacity_utilization_pct:    0,
      gross_revenue:               BigDecimal('0'),
      overall_avg_paid_price:      BigDecimal('0'),
      total_dynamic_lift_dollars:  BigDecimal('0'),
      total_dynamic_lift_pct:      nil,
      performance_count:           perf_count,
      completed_performance_count: completed_perfs
    )
  end
end
