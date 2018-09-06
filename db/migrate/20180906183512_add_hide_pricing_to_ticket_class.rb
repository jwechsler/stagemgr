class AddHidePricingToTicketClass < ActiveRecord::Migration
  def change
    add_column :ticket_classes, :hide_pricing, :boolean
  end
end
