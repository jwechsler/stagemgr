class AddSpecialTicketRangeToTicketClasses < ActiveRecord::Migration[4.2]
  def change
    add_column :ticket_classes, :show_in_pricing_range, :boolean, default: true
    add_column :default_ticket_classes, :show_in_pricing_range, :boolean, default: true
  end
end
