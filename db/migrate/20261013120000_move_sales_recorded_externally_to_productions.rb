class MoveSalesRecordedExternallyToProductions < ActiveRecord::Migration[6.1]
  # A theater can sell one show through an outside box office and the rest
  # in-house, so the flag belongs to the production, not the theater.
  def up
    add_column :productions, :sales_recorded_externally, :boolean, default: false, null: false
    execute <<~SQL.squish
      UPDATE productions pr
      JOIN theaters th ON th.id = pr.theater_id
      SET pr.sales_recorded_externally = 1
      WHERE th.sales_recorded_externally = 1
    SQL
    remove_column :theaters, :sales_recorded_externally
  end

  # A theater is flagged again only when it has productions and every one is flagged.
  def down
    add_column :theaters, :sales_recorded_externally, :boolean, default: false, null: false
    execute <<~SQL.squish
      UPDATE theaters th
      SET th.sales_recorded_externally = 1
      WHERE EXISTS (SELECT 1 FROM productions pr WHERE pr.theater_id = th.id)
        AND NOT EXISTS (SELECT 1 FROM productions pr
                        WHERE pr.theater_id = th.id AND pr.sales_recorded_externally = 0)
    SQL
    remove_column :productions, :sales_recorded_externally
  end
end
