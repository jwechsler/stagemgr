# LEGACY compatibility code. Do not remove without auditing historical
# TicketOrders.
#
# Reserved-seating TicketOrders created by the CSV bulk order importer
# (BulkOrderImport, app/models/resque_jobs/bulk_order_import.rb) before
# 2026-10-01 (commit f62d572c6) carry ONE "aggregate" TicketLineItem per
# ticket class (ticket_count N, seat_assignment_id NULL) beside N
# SeatAssignments with no linked line item.
# No live code path produces this shape any more: every path, the importer
# included, now keeps one line item per seat. This concern bridges the two
# shapes on those imported orders:
#
# * #reconcile_legacy_aggregate_line_items (before_validation): the admin
#   order form renders one row per seat and posts each unlinked seat as a NEW
#   per-seat line item; the aggregate itself is never in the form. Without
#   this, the aggregate and its new per-seat copies both count, doubling
#   number_of_seats. The aggregate gives up one ticket per newly built
#   per-seat item and is destroyed when none remain.
#   First, a new per-seat item for a seat that already has a persisted line
#   item is dropped (a form opened before the backfill split the order posts
#   every seat as new); the persisted item stays authoritative, taking only
#   the posted price_override.
# * #split_seat_from_aggregate! moves one seat off a persisted aggregate onto
#   its own line item. Shared by TicketOrder#sync_reserved_seat_price_overrides
#   and LegacyAggregateSplitter (rake legacy_line_items:split_aggregates).
#
# Orders already in the per-seat shape have no aggregate and are untouched;
# non-seat (holds_seats=false) line items are never aggregates here.
module LegacyAggregateLineItems
  extend ActiveSupport::Concern

  included do
    before_validation :reconcile_legacy_aggregate_line_items, if: :reconcile_legacy_aggregates?
  end

  # Persisted seat-holding line items with no seat link and tickets left: the
  # legacy aggregated-by-class shape.
  def legacy_seat_aggregates
    ticket_line_items.select do |tli|
      tli.persisted? && !tli.marked_for_destruction? && tli.seat_assignment_id.nil? &&
        tli.ticket_count.to_i.positive? && tli.ticket_class&.holds_seats?
    end
  end

  # Moves one seat off a persisted aggregate: a new ticket_count 1 line item
  # linked to the seat, or, when only one ticket is left, the aggregate itself
  # becomes that seat's line item. Writes with update_columns/create! so no
  # order callbacks or mail run.
  def split_seat_from_aggregate!(aggregated, seat_assignment, price_override: seat_assignment.price_override)
    if aggregated.ticket_count > 1
      aggregated.update_columns(ticket_count: aggregated.ticket_count - 1)
      ticket_line_items.create!(
        ticket_class_id: seat_assignment.ticket_class_id,
        ticket_count: 1,
        seat_assignment_id: seat_assignment.id,
        price_override: price_override,
        generated_from_split: aggregated.generated_from_split
      )
    else
      aggregated.update_columns(seat_assignment_id: seat_assignment.id, price_override: price_override)
    end
  end

  private

  def reconcile_legacy_aggregates?
    !exchanging? && performance&.production&.has_reserved_seating?
  end

  def reconcile_legacy_aggregate_line_items
    drop_duplicate_per_seat_line_items
    aggregates = legacy_seat_aggregates
    return if aggregates.empty?

    new_counts = new_per_seat_line_items.group_by(&:ticket_class_id).transform_values(&:size)
    aggregates.each do |aggregated|
      remaining = new_counts.fetch(aggregated.ticket_class_id, 0)
      next if remaining.zero?

      taken = [remaining, aggregated.ticket_count].min
      new_counts[aggregated.ticket_class_id] = remaining - taken
      aggregated.ticket_count -= taken
      aggregated.mark_for_destruction unless aggregated.ticket_count.positive?
    end
  end

  # Marked for destruction so autosave never inserts it, and zeroed because
  # number_of_seats and ticket_stock_available still count marked items.
  def drop_duplicate_per_seat_line_items
    persisted_by_seat = ticket_line_items.select do |tli|
      tli.persisted? && !tli.marked_for_destruction? && tli.seat_assignment_id.present?
    end.index_by(&:seat_assignment_id)
    new_per_seat_line_items.each do |duplicate|
      persisted = persisted_by_seat[duplicate.seat_assignment_id]
      next if persisted.nil?

      persisted.price_override = duplicate.price_override unless duplicate.price_override.nil?
      duplicate.ticket_count = 0
      duplicate.mark_for_destruction
    end
  end

  # Only per-seat items built in this save count: a persisted one is already
  # balanced against the aggregate (sync_reserved_seat_price_overrides split it
  # off), so subtracting it again would undercount a valid order.
  def new_per_seat_line_items
    ticket_line_items.select do |tli|
      tli.new_record? && !tli.marked_for_destruction? && tli.seat_assignment_id.present? &&
        tli.ticket_count.to_i.positive?
    end
  end
end
