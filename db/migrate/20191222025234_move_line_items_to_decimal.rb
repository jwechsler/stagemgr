class MoveLineItemsToDecimal < ActiveRecord::Migration[4.2]
  def change
    rename_column :line_items, :price_override, :price_override_old
    rename_column :line_items, :amount, :amount_old 
    add_column :line_items, :price_override, :decimal, precision: 8, scale: 2
    add_column :line_items, :amount, :decimal, precision: 8, scale: 2, default: 0.0
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE LINE_ITEMS SET PRICE_OVERRIDE = PRICE_OVERRIDE_OLD, AMOUNT = AMOUNT_OLD;
        SQL
      end
      dir.down do
        execute <<-SQL
          UPDATE LINE_ITEMS SET PRICE_OVERRIDE_OLD = PRICE_OVERRIDE, AMOUNT_OLD = AMOUNT;
        SQL
      end
    end
    remove_column :line_items, :amount_old, :float
    remove_column :line_items, :price_override_old, :float
  end

end
