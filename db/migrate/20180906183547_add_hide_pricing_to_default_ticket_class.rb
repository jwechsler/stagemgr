class AddHidePricingToDefaultTicketClass < ActiveRecord::Migration[4.2]
  def change
    add_column :default_ticket_classes, :hide_pricing, :boolean
  end
end
