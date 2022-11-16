class AddHidePricingToTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :ticket_classes, :hide_pricing, :boolean
  end
end
