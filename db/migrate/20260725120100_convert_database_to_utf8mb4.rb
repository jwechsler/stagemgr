# Converts every application table to utf8mb4 / utf8mb4_0900_ai_ci.
#
# The database grew up mixed: 28 tables latin1, 10 utf8mb3, 10 already
# utf8mb4_0900_ai_ci. The latin1 tables physically cannot store characters box
# office staff paste from Word and e-mail, so MySQL rejects the write outright:
#
#   Mysql2::Error: Incorrect string value: '\xEF\xBB\xBFBla...'
#     for column 'special_feature_display_markdown' at row 1
#
# Run ShrinkAddressSearchIndexForUtf8mb4 first -- addresses cannot convert until
# index_address_search is prefix-limited.
#
# BEFORE RUNNING IN PRODUCTION -- see docs/runbooks/utf8mb4-migration.md.
# CONVERT TO CHARACTER SET changes column byte widths, so InnoDB rejects
# ALGORITHM=INPLACE and rebuilds each table under ALGORITHM=COPY, holding a
# lock that blocks writes for the duration. On the large tables (addresses,
# orders, audits, payments) either take a maintenance window or drive the
# rebuild with gh-ost / pt-online-schema-change. Take a dump first.
class ConvertDatabaseToUtf8mb4 < ActiveRecord::Migration[6.1]
  CHARSET = 'utf8mb4'.freeze
  COLLATION = 'utf8mb4_0900_ai_ci'.freeze

  # Rails bookkeeping: ASCII only, nothing joins them, and Rails writes to
  # schema_migrations while this migration is running. Left alone deliberately.
  SKIP = %w[schema_migrations ar_internal_metadata].freeze

  def up
    execute "ALTER DATABASE `#{connection.current_database}` " \
            "CHARACTER SET #{CHARSET} COLLATE #{COLLATION}"

    # The 17 foreign keys transiently span mismatched charsets while the loop
    # runs, which MySQL would otherwise reject as incompatible column types.
    execute 'SET FOREIGN_KEY_CHECKS = 0'

    unconverted_tables.each do |table|
      say_with_time "converting #{table}" do
        execute "ALTER TABLE `#{table}` CONVERT TO CHARACTER SET #{CHARSET} COLLATE #{COLLATION}"
      end
    end
  ensure
    execute 'SET FOREIGN_KEY_CHECKS = 1'
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Reverting to latin1 would silently destroy every character latin1 cannot represent.'
  end

  private

  # Filtering on the current collation makes the migration resumable: if it dies
  # partway through a large table rebuild, re-running skips what already landed.
  def unconverted_tables
    select_values(<<~SQL.squish) - SKIP
      SELECT TABLE_NAME FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_TYPE = 'BASE TABLE'
        AND TABLE_COLLATION <> '#{COLLATION}'
      ORDER BY TABLE_NAME
    SQL
  end
end
