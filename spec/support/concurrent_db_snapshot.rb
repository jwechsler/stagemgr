# For :concurrent_db examples, which run outside the per-example transaction
# (each thread needs its own committed view of the data): snapshot the tables
# before the example and delete every row it created afterwards.
#
#   include ConcurrentDbSnapshot
#   around { |example| with_db_snapshot { example.run } }
module ConcurrentDbSnapshot
  # Tables without an id column cannot be trimmed by id; an example must leave
  # them as it found them.
  IGNORED_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  def with_db_snapshot
    before = db_snapshot
    yield
  ensure
    restore_db_snapshot!(before) if before
  end

  private

  def db_connection
    ActiveRecord::Base.connection
  end

  def id_tables
    (db_connection.tables - IGNORED_TABLES).select { |t| db_connection.column_exists?(t, :id) }
  end

  def idless_tables
    db_connection.tables - IGNORED_TABLES - id_tables
  end

  def db_snapshot
    { max_ids: id_tables.index_with { |t| db_connection.select_value("SELECT COALESCE(MAX(id), 0) FROM `#{t}`").to_i },
      counts: idless_tables.index_with { |t| db_connection.select_value("SELECT COUNT(*) FROM `#{t}`").to_i } }
  end

  # Deletes every row created since the snapshot; fails loudly if an id-less
  # (join) table changed, rather than leaving rows behind for other specs.
  def restore_db_snapshot!(before)
    db_connection.execute('SET FOREIGN_KEY_CHECKS = 0')
    before[:max_ids].each do |table, max_id|
      db_connection.execute("DELETE FROM `#{table}` WHERE id > #{max_id}")
    end
  ensure
    db_connection.execute('SET FOREIGN_KEY_CHECKS = 1')
    changed = before[:counts].reject do |table, count|
      db_connection.select_value("SELECT COUNT(*) FROM `#{table}`").to_i == count
    end
    raise "concurrent_db example left rows in #{changed.keys.join(', ')}" if changed.any?
  end
end
