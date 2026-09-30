require 'rails_helper'

# Concurrency regression for SeatAssignmentsController#reserve: a double click
# sends two reserves for one seat at the same moment. Without the row lock
# (sa.lock!) both requests miss the seat's TicketLineItem in
# upsert_ticket_line_item_for and both insert, and the second fails on
# index_line_items_on_seat_assignment_id (RecordNotUnique, which the app's
# error handling turns into a redirect instead of the JSON the page expects).
#
# Each thread needs its own committed view of the data, so this runs outside
# the per-example transaction (:concurrent_db) and deletes what it created.
module ConcurrentReserveRace
  RACE_ITERATIONS = Integer(ENV.fetch('RACE_ITERATIONS', 5))
  THREAD_COUNT = 2
  THREAD_JOIN_TIMEOUT = 30
  # Held inside reserve's transaction, between claiming the seat and upserting
  # its line item, so the second request reliably arrives mid-transaction
  # (unaided, the critical window is a few ms and the race rarely lands).
  RACE_WINDOW_SECONDS = 0.2

  # Tables without an id column cannot be trimmed by id; this example must
  # leave them as it found them.
  IGNORED_TABLES = %w[schema_migrations ar_internal_metadata].freeze
end

RSpec.describe 'SeatAssignmentsController#reserve under concurrent requests',
               :concurrent_db, type: :request do
  self.use_transactional_tests = false

  def db_connection
    ActiveRecord::Base.connection
  end

  def id_tables
    (db_connection.tables - ConcurrentReserveRace::IGNORED_TABLES).select { |t| db_connection.column_exists?(t, :id) }
  end

  def idless_tables
    db_connection.tables - ConcurrentReserveRace::IGNORED_TABLES - id_tables
  end

  def snapshot
    { max_ids: id_tables.index_with { |t| db_connection.select_value("SELECT COALESCE(MAX(id), 0) FROM `#{t}`").to_i },
      counts: idless_tables.index_with { |t| db_connection.select_value("SELECT COUNT(*) FROM `#{t}`").to_i } }
  end

  # Deletes every row created since the snapshot; fails loudly if an id-less
  # (join) table changed, rather than leaving rows behind for other specs.
  def restore!(before)
    db_connection.execute('SET FOREIGN_KEY_CHECKS = 0')
    before[:max_ids].each do |table, max_id|
      db_connection.execute("DELETE FROM `#{table}` WHERE id > #{max_id}")
    end
  ensure
    db_connection.execute('SET FOREIGN_KEY_CHECKS = 1')
    changed = before[:counts].reject do |table, count|
      db_connection.select_value("SELECT COUNT(*) FROM `#{table}`").to_i == count
    end
    raise "concurrent reserve spec left rows in #{changed.keys.join(', ')}" if changed.any?
  end

  around do |example|
    before = snapshot
    begin
      example.run
    ensure
      restore!(before)
    end
  end

  # One reserve through the full stack (routing, controller, real
  # transaction), on a thread with its own connection and session.
  def reserve(performance, seat, order, ticket_class)
    ActiveRecord::Base.connection_pool.with_connection do
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.post(reserve_performance_seat_assignments_path(performance, format: :json),
                   params: { id: seat.id, order_uuid: order.uuid, ticket_class_id: ticket_class.id })
      [session.response.status, reserve_status(session.response)]
    end
  end

  # One thread per ticket class, released together by a barrier.
  # The JSON status, or the start of the body when it is not JSON (the app's
  # error handling answers a failed request with a redirect page).
  def reserve_status(response)
    JSON.parse(response.body)['status']
  rescue JSON::ParserError
    response.body.to_s[0, 80]
  end

  def race(performance, seat, order, ticket_classes)
    barrier = Concurrent::CyclicBarrier.new(ticket_classes.size)
    threads = ticket_classes.map do |ticket_class|
      Thread.new do
        barrier.wait
        reserve(performance, seat, order, ticket_class)
      rescue StandardError => e
        e
      end
    end
    threads.map { |t| t.join(ConcurrentReserveRace::THREAD_JOIN_TIMEOUT)&.value || :timed_out }
  end

  # Put the raced seat back so the next iteration races for it again.
  def free_seat!(seat)
    TicketLineItem.where(seat_assignment_id: seat.id).delete_all
    seat.reload.update_columns(status: SeatAssignment::AVAILABLE, order_uuid: nil, ticket_class_id: nil)
  end

  let(:performance) do
    venue = FactoryBot.create(:venue)
    seat_map = FactoryBot.create(:seat_map, venue: venue)
    production = FactoryBot.create(:production, venue: venue, seat_map: seat_map)
    FactoryBot.create(:performance, production: production)
  end
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance) }
  let(:ticket_class) { order.ticket_line_items.first.ticket_class }
  let(:seats) do
    SeatAssignment.where(performance_id: performance.id, status: SeatAssignment::AVAILABLE).order(:id).first(2)
  end
  let(:seat) { seats.last }

  before do
    # Warm up (loads constants and routes once, off the race).
    expect(reserve(performance, seats.first, order, ticket_class)).to eq([200, 'assigned'])

    allow_any_instance_of(SeatAssignment).to receive(:assign_to_order).and_wrap_original do |original, *args|
      claimed = original.call(*args)
      sleep ConcurrentReserveRace::RACE_WINDOW_SECONDS
      claimed
    end
  end

  # A double click: the same class twice. Unlocked, the second request reads a
  # stale seat and answers "available" for a seat it holds.
  it 'answers assigned to both and keeps one line item when the same class races' do
    ConcurrentReserveRace::RACE_ITERATIONS.times do |i|
      results = race(performance, seat, order, [ticket_class] * ConcurrentReserveRace::THREAD_COUNT)

      expect(results).to eq([[200, 'assigned']] * ConcurrentReserveRace::THREAD_COUNT), "iteration #{i}: #{results.inspect}"
      expect(TicketLineItem.where(seat_assignment_id: seat.id).pluck(:order_id)).to eq([order.id])
      free_seat!(seat)
    end
  end

  # Two classes for one seat at once. Unlocked, both insert a line item and the
  # second fails on index_line_items_on_seat_assignment_id (RecordNotUnique).
  it 'keeps one line item without RecordNotUnique when two classes race' do
    other_class = FactoryBot.create(:ticket_class, production: performance.production, class_code: 'RACE2')
    TicketClassAllocation.find_or_initialize_by(performance: performance, ticket_class: other_class)
                         .update!(available: true)

    ConcurrentReserveRace::RACE_ITERATIONS.times do |i|
      results = race(performance, seat, order, [ticket_class, other_class])

      expect(results.map(&:first)).to eq([200] * ConcurrentReserveRace::THREAD_COUNT), "iteration #{i}: #{results.inspect}"
      tlis = TicketLineItem.where(seat_assignment_id: seat.id)
      expect(tlis.pluck(:order_id)).to eq([order.id])
      expect(tlis.first.ticket_class_id).to eq(seat.reload.ticket_class_id)
      free_seat!(seat)
    end
  end
end
