class MoveTicketClassesToDecimal < ActiveRecord::Migration
  def change
    rename_column :ticket_classes, :ticketing_fee, :ticketing_fee_old
    rename_column :ticket_classes, :ticket_price, :ticket_price_old
    add_column :ticket_classes, :ticketing_fee, :decimal, precision: 8, scale: 2, default: 0.0
    add_column :ticket_classes, :ticket_price, :decimal, precision: 8, scale: 2, default: 0.0
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE TICKET_CLASSES SET TICKETING_FEE = TICKETING_FEE_OLD, TICKET_PRICE = TICKET_PRICE_OLD;
        SQL
      end
      dir.down do
        execute <<-SQL
          UPDATE TICKET_CLASSES SET TICKETING_FEE_OLD = TICKETING_FEE, TICKET_PRICE_OLD = TICKET_PRICE;
        SQL
      end
    end
    remove_column :ticket_classes, :ticket_price_old, :float
    remove_column :ticket_classes, :ticketing_fee_old, :float
  end

end
