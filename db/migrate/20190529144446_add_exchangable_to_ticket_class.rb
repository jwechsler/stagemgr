class AddExchangableToTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :ticket_classes, :exchangeable, :boolean, default:false
    add_column :default_ticket_classes, :exchangeable, :boolean, default:false
  end
end
