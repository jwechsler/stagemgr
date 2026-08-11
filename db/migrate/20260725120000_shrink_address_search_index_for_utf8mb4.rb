# Prerequisite for ConvertDatabaseToUtf8mb4.
#
# index_address_search covers four varchar(255) columns. InnoDB caps an index key
# at 3072 bytes, and the index only fits today because addresses is utf8mb3:
# 4 x 255 x 3 = 3060 bytes, twelve bytes under the limit. Under utf8mb4 the same
# index needs 4080 bytes and the conversion fails with
#
#   ERROR 1071: Specified key was too long; max key length is 3072 bytes
#
# Prefix lengths bring it to 1120 bytes. The index exists to serve the duplicate
# detection query in Address#find_matches (app/models/address.rb), which compares
# all four columns with =, so a prefix index still satisfies it.
#
# Deploy and verify this ahead of the charset conversion.
class ShrinkAddressSearchIndexForUtf8mb4 < ActiveRecord::Migration[6.1]
  INDEX = 'index_address_search'.freeze
  COLUMNS = %i[street_number street city search_name].freeze
  PREFIXES = { street_number: 20, street: 100, city: 60, search_name: 100 }.freeze

  def up
    remove_index :addresses, name: INDEX
    add_index :addresses, COLUMNS, name: INDEX, length: PREFIXES
  end

  # Only reversible while addresses still stores 3 bytes or fewer per character.
  # Once the table is utf8mb4 the full-length index no longer fits.
  def down
    remove_index :addresses, name: INDEX
    add_index :addresses, COLUMNS, name: INDEX
  end
end
