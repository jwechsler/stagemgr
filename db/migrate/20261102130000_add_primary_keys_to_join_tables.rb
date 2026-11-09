class AddPrimaryKeysToJoinTables < ActiveRecord::Migration[6.1]
  # Production's managed MySQL runs with sql_require_primary_key=1, which
  # rejects tables without a primary key. These habtm join tables never had
  # one, so each gets a composite key over its two foreign keys. Null and
  # duplicate pairs (addresses_productions accumulated many) are removed first.
  TABLES = {
    addresses_productions: %i[address_id production_id],
    performances_special_features: %i[performance_id special_feature_id],
    theaters_users: %i[theater_id user_id],
    resourced_ticket_classes_venues: %i[resourced_ticket_class_id venue_id]
  }.freeze

  # Covered by the new primary keys, which lead with the same columns.
  REDUNDANT_INDEXES = {
    addresses_productions: { name: "index_addresses_productions_on_address_id_and_production_id", unique: false },
    resourced_ticket_classes_venues: { name: "index_rtc_venues_on_rtc_and_venue", unique: true }
  }.freeze

  ALREADY_NOT_NULL = %i[resourced_ticket_classes_venues].freeze

  def up
    TABLES.each do |table, (first, second)|
      execute "DELETE FROM #{table} WHERE #{first} IS NULL OR #{second} IS NULL"
      dedupe(table, first, second)
      change_column_null table, first, false
      change_column_null table, second, false
      execute "ALTER TABLE #{table} ADD PRIMARY KEY (#{first}, #{second})"
    end

    REDUNDANT_INDEXES.each { |table, index| remove_index table, name: index[:name] }

    # production.addresses (attendee reports, mailing lists) looks up by
    # production_id, which the address_id-first primary key cannot serve.
    add_index :addresses_productions, :production_id
  end

  # Rows removed as nulls or duplicates in #up are not restored.
  def down
    remove_index :addresses_productions, :production_id

    TABLES.each do |table, (first, second)|
      execute "ALTER TABLE #{table} DROP PRIMARY KEY"
      next if ALREADY_NOT_NULL.include?(table)

      change_column_null table, first, true
      change_column_null table, second, true
    end

    REDUNDANT_INDEXES.each do |table, index|
      add_index table, TABLES.fetch(table), name: index[:name], unique: index[:unique]
    end
  end

  private

  def dedupe(table, first, second)
    execute "CREATE TEMPORARY TABLE #{table}_distinct (PRIMARY KEY (#{first}, #{second})) AS SELECT DISTINCT #{first}, #{second} FROM #{table}"
    execute "DELETE FROM #{table}"
    execute "INSERT INTO #{table} (#{first}, #{second}) SELECT #{first}, #{second} FROM #{table}_distinct"
    execute "DROP TEMPORARY TABLE #{table}_distinct"
  end
end
