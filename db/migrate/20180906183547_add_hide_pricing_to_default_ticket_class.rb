class AddHidePricingToDefaultTicketClass < ActiveRecord::Migration
  def change
    add_column :default_ticket_classes, :hide_pricing, :boolean
  end
end
