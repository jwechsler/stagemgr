class TicketRevenueAnalysis
  BucketResult = Struct.new(
    :name, :ticket_class_ids, :class_codes, :entry_price, :bucket_type,
    :paid_count, :avg_paid_price, :price_min, :price_max,
    :ladder_distribution, :class_breakdown, :actual_gross,
    :flat_base_gross, :dynamic_lift_dollars, :dynamic_lift_pct,
    :bucket_allocation, :allocation_from_limit, :sell_through_pct, :allocation_cap_hit,
    keyword_init: true
  )

  Summary = Struct.new(
    :production, :buckets, :comp_count, :total_capacity,
    :total_paid, :capacity_utilization_pct, :gross_revenue,
    :cash_collected,
    :overall_avg_paid_price, :total_dynamic_lift_dollars, :total_dynamic_lift_pct,
    :performance_count, :completed_performance_count,
    :special_offer_usage,
    keyword_init: true
  )

  OfferUsage = Struct.new(:code, :description, :uses, :total_discount, :class_swap, keyword_init: true)

  def initialize(production)
    @production = production
  end

  def compute
    Rails.cache.fetch(cache_key, expires_in: 1.hour) { uncached_compute }
  end

  private

  def cache_key
    "ticket_revenue_analysis/#{@production.id}/v5/#{@production.updated_at.to_i}"
  end

  def uncached_compute
    ticket_classes  = @production.ticket_classes.to_a
    perf_count      = @production.performances.count
    completed_perfs = @production.performances.where('performance_date < ?', Date.today).count

    return empty_summary(perf_count, completed_perfs) if ticket_classes.empty?

    class_by_code = ticket_classes.index_by(&:class_code)
    class_by_id   = ticket_classes.index_by(&:id)

    # Build promotion edges across all allocations for this production
    edges        = build_promotion_edges(class_by_code)
    promoted_ids = edges.flat_map { |a, b| [a, b] }.to_set

    # Classify by precedence: Comp > Dynamic > Zero-rev > Singleton
    comp_tcs     = ticket_classes.select(&:complimentary?)
    comp_ids     = comp_tcs.map(&:id).to_set
    remaining    = ticket_classes.reject(&:complimentary?)

    dynamic_tcs = remaining.select { |tc| promoted_ids.include?(tc.id) }
    dynamic_ids = dynamic_tcs.map(&:id).to_set
    non_dynamic = remaining.reject { |tc| dynamic_ids.include?(tc.id) }

    zero_rev_tcs  = non_dynamic.select { |tc| effective_class_price(tc) <= 0 }
    zero_rev_ids  = zero_rev_tcs.map(&:id).to_set
    singleton_tcs = non_dynamic.reject { |tc| zero_rev_ids.include?(tc.id) }

    # Dynamic groups via union-find; restrict edges to non-comp dynamic classes
    dynamic_edges  = edges.select { |a, b| dynamic_ids.include?(a) && dynamic_ids.include?(b) }
    dynamic_groups = union_find_buckets(dynamic_ids.to_a, dynamic_edges)

    line_items      = fetch_line_items
    allocation_data = fetch_allocation_data
    fallback_alloc  = (@production.capacity || 0) * perf_count

    bucket_results = []

    # Dynamic pricing buckets
    dynamic_groups.each do |tc_ids|
      entry_price = entry_price_for_bucket(tc_ids, dynamic_edges, class_by_id)
      paid_rows   = line_items.select { |r| tc_ids.include?(r[:tc_id]) }
      result = build_bucket(
        tc_ids: tc_ids,
        class_by_id: class_by_id,
        entry_price: entry_price,
        paid_rows: paid_rows,
        allocation_data: allocation_data,
        fallback_allocation: fallback_alloc,
        bucket_type: :dynamic
      )
      bucket_results << result if result
    end

    # Singleton buckets (non-promoted, positive price, non-comp)
    singleton_tcs.each do |tc|
      paid_rows = line_items.select { |r| r[:tc_id] == tc.id }
      result = build_bucket(
        tc_ids: [tc.id],
        class_by_id: class_by_id,
        entry_price: effective_class_price(tc),
        paid_rows: paid_rows,
        allocation_data: allocation_data,
        fallback_allocation: fallback_alloc,
        bucket_type: :singleton
      )
      bucket_results << result if result
    end

    # Sort paid buckets by avg price descending
    bucket_results.sort_by! { |b| -(b.avg_paid_price || 0) }

    # Zero-revenue bucket appended after sorted paid buckets
    zero_rev_count = 0
    if zero_rev_tcs.any?
      zero_rows      = line_items.select { |r| zero_rev_ids.include?(r[:tc_id]) }
      zero_rev_count = zero_rows.sum { |r| r[:count] }
      bucket_results << build_zero_rev_bucket(zero_rev_tcs, class_by_id, zero_rows, allocation_data, fallback_alloc)
    end

    # Comp bucket always last
    comp_count = 0
    if comp_tcs.any?
      comp_rows  = line_items.select { |r| comp_ids.include?(r[:tc_id]) }
      comp_count = comp_rows.sum { |r| r[:count] }
      bucket_results << build_comp_bucket(comp_tcs, class_by_id, comp_rows, allocation_data, fallback_alloc)
    end

    paid_buckets  = bucket_results.select { |b| %i[dynamic singleton].include?(b.bucket_type) }
    total_paid    = paid_buckets.sum(&:paid_count)
    total_cap     = (@production.capacity || 0) * perf_count
    gross_revenue = paid_buckets.sum(&:actual_gross)
    overall_avg   = total_paid > 0 ? gross_revenue / total_paid : BigDecimal('0')

    dynamic_buckets = bucket_results.select { |b| b.bucket_type == :dynamic }
    total_lift      = dynamic_buckets.sum(&:dynamic_lift_dollars)
    total_flat_base = dynamic_buckets.sum(&:flat_base_gross)
    total_lift_pct  = total_flat_base > 0 ? (total_lift / total_flat_base * 100).round(2) : nil
    issued          = total_paid + comp_count + zero_rev_count
    cap_util        = total_cap > 0 ? (issued.to_f / total_cap * 100).round(1) : 0

    Summary.new(
      production:                  @production,
      buckets:                     bucket_results,
      comp_count:                  comp_count,
      total_capacity:              total_cap,
      total_paid:                  total_paid,
      capacity_utilization_pct:    cap_util,
      gross_revenue:               gross_revenue,
      cash_collected:              RevenueCalculator.for_production(@production).collected,
      overall_avg_paid_price:      overall_avg,
      total_dynamic_lift_dollars:  total_lift,
      total_dynamic_lift_pct:      total_lift_pct,
      performance_count:           perf_count,
      completed_performance_count: completed_perfs,
      special_offer_usage: compute_special_offer_usage
    )
  end

  def compute_special_offer_usage
    items = SpecialOfferLineItem
            .joins('INNER JOIN orders ON orders.id = line_items.order_id')
            .joins('INNER JOIN performances ON performances.id = orders.performance_id')
            .where(performances: { production_id: @production.id })
            .where(orders: { status: Order::FINALIZED_STATUSES })
            .includes(:special_offer, :order)

    items.group_by(&:special_offer_id).filter_map do |_offer_id, list|
      offer = list.first.special_offer
      next nil unless offer

      total_discount = list.sum { |li| li.price.to_f.abs }
      OfferUsage.new(
        code: offer.code,
        description: offer.to_s,
        uses: list.size,
        total_discount: BigDecimal(total_discount.to_s),
        class_swap: offer.is_a?(TicketClassSpecialOffer)
      )
    end.sort_by { |u| -u.uses }
  end

  def build_promotion_edges(class_by_code)
    TicketClassAllocation
      .joins('INNER JOIN performances ON performances.id = ticket_class_allocations.performance_id')
      .where(performances: { production_id: @production.id })
      .where(shiftable: true)
      .where.not(shift_to_code: nil)
      .pluck('ticket_class_allocations.ticket_class_id', 'ticket_class_allocations.shift_to_code')
      .filter_map do |from_id, to_code|
        to_tc = class_by_code[to_code]
        to_tc && to_tc.id != from_id ? [from_id, to_tc.id] : nil
      end
      .uniq
  end

  def union_find_buckets(all_ids, edges)
    parent = all_ids.to_h { |id| [id, id] }

    find = lambda { |x|
      parent[x] = find.call(parent[x]) unless parent[x] == x
      parent[x]
    }

    edges.each { |a, b| parent[find.call(a)] = find.call(b) }

    all_ids.group_by { |id| find.call(id) }.values
  end

  def entry_price_for_bucket(tc_ids, _edges, class_by_id)
    tc_ids.map { |id| class_by_id[id] }.compact
          .map { |tc| effective_class_price(tc) }
          .min || BigDecimal('0')
  end

  def effective_class_price(ticket_class)
    base = if ticket_class.ticket_price == 0 && ticket_class.royalty_amount
             ticket_class.royalty_amount
           else
             ticket_class.ticket_price
           end
    base - (ticket_class.ticketing_fee || BigDecimal('0'))
  end

  def fetch_line_items
    TicketLineItem
      .joins('INNER JOIN orders ON orders.id = line_items.order_id')
      .joins('INNER JOIN performances ON performances.id = orders.performance_id')
      .joins('INNER JOIN ticket_classes tc ON tc.id = line_items.ticket_class_id')
      .where(performances: { production_id: @production.id })
      .where(orders: { status: Order::FINALIZED_STATUSES })
      .pluck(
        'line_items.ticket_class_id',
        'line_items.ticket_count',
        'line_items.price_override',
        'tc.ticket_price',
        'tc.royalty_amount',
        'tc.complimentary',
        'tc.ticketing_fee'
      )
      .map do |tc_id, count, override, price, royalty, comp, ticketing_fee|
        {
          tc_id: tc_id,
          count: count.to_i,
          override: override ? BigDecimal(override.to_s) : nil,
          price: BigDecimal(price.to_s),
          royalty: royalty ? BigDecimal(royalty.to_s) : nil,
          comp: [1, true].include?(comp),
          ticketing_fee: ticketing_fee ? BigDecimal(ticketing_fee.to_s) : BigDecimal('0')
        }
      end
  end

  def fetch_allocation_data
    rows = TicketClassAllocation
           .joins('INNER JOIN performances ON performances.id = ticket_class_allocations.performance_id')
           .where(performances: { production_id: @production.id })
           .pluck(
             'ticket_class_allocations.ticket_class_id',
             'ticket_class_allocations.ticket_limit'
           )

    rows.group_by { |tc_id, _| tc_id }.each_with_object({}) do |(tc_id, pairs), h|
      limits = pairs.map { |_, limit| limit }.compact
      h[tc_id] = {
        total_limit: limits.any? ? limits.sum : nil,
        has_any_limit: limits.any?
      }
    end
  end

  def effective_price(row)
    return nil if row[:comp]

    base = if row[:price] == 0 && row[:royalty]
             row[:royalty]
           elsif row[:override]
             row[:override]
           else
             row[:price]
           end
    base - row[:ticketing_fee]
  end

  def compute_allocation(tc_ids, allocation_data, fallback_allocation)
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
    [bucket_alloc, from_limit]
  end

  def build_bucket(tc_ids:, class_by_id:, entry_price:, paid_rows:, allocation_data:, fallback_allocation:,
                   bucket_type:)
    priced_rows = paid_rows.filter_map do |r|
      ep = effective_price(r)
      ep ? { tc_id: r[:tc_id], count: r[:count], price: ep } : nil
    end

    total_count = priced_rows.sum { |r| r[:count] }
    return nil if total_count <= 0

    weighted_sum = priced_rows.sum { |r| r[:price] * r[:count] }
    avg_price    = weighted_sum / total_count
    price_min    = priced_rows.pluck(:price).min
    price_max    = priced_rows.pluck(:price).max

    ladder = priced_rows.each_with_object(Hash.new(0)) do |r, h|
      h[r[:price].to_f.round(2)] += r[:count]
    end

    breakdown = class_breakdown_for(priced_rows, total_count, class_by_id)

    bucket_alloc, from_limit = compute_allocation(tc_ids, allocation_data, fallback_allocation)

    sell_through   = bucket_alloc > 0 ? (total_count.to_f / bucket_alloc * 100).round(1) : nil
    cap_hit        = from_limit && bucket_alloc > 0 && total_count >= bucket_alloc
    flat_base      = entry_price * total_count
    lift_dollars   = weighted_sum - flat_base
    lift_pct       = flat_base > 0 ? (lift_dollars / flat_base * 100).round(2) : nil
    class_codes    = tc_ids.map { |id| class_by_id[id]&.class_code }.compact

    BucketResult.new(
      name: class_codes.join('/'),
      ticket_class_ids: tc_ids,
      class_codes: class_codes,
      entry_price: entry_price,
      bucket_type: bucket_type,
      paid_count: total_count,
      avg_paid_price: avg_price,
      price_min: price_min,
      price_max: price_max,
      ladder_distribution: ladder,
      class_breakdown: breakdown,
      actual_gross: weighted_sum,
      flat_base_gross: flat_base,
      dynamic_lift_dollars: lift_dollars,
      dynamic_lift_pct: lift_pct,
      bucket_allocation: bucket_alloc,
      allocation_from_limit: from_limit,
      sell_through_pct: sell_through,
      allocation_cap_hit: cap_hit
    )
  end

  def class_breakdown_for(priced_rows, total_count, class_by_id)
    priced_rows.group_by { |r| r[:tc_id] }.map do |tc_id, rows|
      count    = rows.sum { |r| r[:count] }
      gross    = rows.sum { |r| r[:price] * r[:count] }
      avg      = count > 0 ? gross / count : BigDecimal('0')
      pct      = total_count > 0 ? (count.to_f / total_count * 100).round(1) : 0
      {
        class_code: class_by_id[tc_id]&.class_code,
        ticket_count: count,
        avg_price: avg,
        gross: gross,
        pct_of_bucket: pct
      }
    end.sort_by { |h| -h[:avg_price] }
  end

  def build_comp_bucket(comp_tcs, _class_by_id, comp_rows, allocation_data, fallback_allocation)
    tc_ids      = comp_tcs.map(&:id)
    class_codes = comp_tcs.map(&:class_code)
    total_count = comp_rows.sum { |r| r[:count] }

    bucket_alloc, from_limit = compute_allocation(tc_ids, allocation_data, fallback_allocation)
    sell_through = bucket_alloc > 0 ? (total_count.to_f / bucket_alloc * 100).round(1) : nil
    cap_hit      = from_limit && bucket_alloc > 0 && total_count >= bucket_alloc

    BucketResult.new(
      name: 'Comp',
      ticket_class_ids: tc_ids,
      class_codes: class_codes,
      entry_price: BigDecimal('0'),
      bucket_type: :comp,
      paid_count: total_count,
      avg_paid_price: BigDecimal('0'),
      price_min: nil,
      price_max: nil,
      ladder_distribution: {},
      class_breakdown: [],
      actual_gross: BigDecimal('0'),
      flat_base_gross: BigDecimal('0'),
      dynamic_lift_dollars: BigDecimal('0'),
      dynamic_lift_pct: nil,
      bucket_allocation: bucket_alloc,
      allocation_from_limit: from_limit,
      sell_through_pct: sell_through,
      allocation_cap_hit: cap_hit
    )
  end

  def build_zero_rev_bucket(zero_rev_tcs, _class_by_id, zero_rows, allocation_data, fallback_allocation)
    tc_ids      = zero_rev_tcs.map(&:id)
    class_codes = zero_rev_tcs.map(&:class_code)
    total_count = zero_rows.sum { |r| r[:count] }

    bucket_alloc, from_limit = compute_allocation(tc_ids, allocation_data, fallback_allocation)
    sell_through = bucket_alloc > 0 ? (total_count.to_f / bucket_alloc * 100).round(1) : nil
    cap_hit      = from_limit && bucket_alloc > 0 && total_count >= bucket_alloc

    BucketResult.new(
      name: 'No Revenue',
      ticket_class_ids: tc_ids,
      class_codes: class_codes,
      entry_price: BigDecimal('0'),
      bucket_type: :zero_rev,
      paid_count: total_count,
      avg_paid_price: BigDecimal('0'),
      price_min: nil,
      price_max: nil,
      ladder_distribution: {},
      class_breakdown: [],
      actual_gross: BigDecimal('0'),
      flat_base_gross: BigDecimal('0'),
      dynamic_lift_dollars: BigDecimal('0'),
      dynamic_lift_pct: nil,
      bucket_allocation: bucket_alloc,
      allocation_from_limit: from_limit,
      sell_through_pct: sell_through,
      allocation_cap_hit: cap_hit
    )
  end

  def empty_summary(perf_count, completed_perfs)
    Summary.new(
      production: @production,
      buckets: [],
      comp_count: 0,
      total_capacity: 0,
      total_paid: 0,
      capacity_utilization_pct: 0,
      gross_revenue: BigDecimal('0'),
      cash_collected: BigDecimal('0'),
      overall_avg_paid_price: BigDecimal('0'),
      total_dynamic_lift_dollars: BigDecimal('0'),
      total_dynamic_lift_pct: nil,
      performance_count: perf_count,
      completed_performance_count: completed_perfs,
      special_offer_usage: []
    )
  end
end
