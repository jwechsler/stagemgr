class AddActivatedAtToPerformances < ActiveRecord::Migration[6.1]
  # activated_at: the first time a performance became Active; never cleared.
  # Existing Active performances are assumed active since creation. The
  # production_id index also serves the advance-sales query, which starts
  # from productions and joins down to performances.
  def up
    add_column :performances, :activated_at, :datetime
    add_index :performances, :production_id
    execute(<<~SQL.squish)
      UPDATE performances SET activated_at = created_at
      WHERE status = 'Active' AND activated_at IS NULL
    SQL
  end

  def down
    remove_index :performances, :production_id
    remove_column :performances, :activated_at
  end
end
