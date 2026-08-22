class AddZoneIdToDefaultTicketClasses < ActiveRecord::Migration[6.1]
  # Mirrors ticket_classes.zone_id (20260702210200). Productions copy every
  # default attribute into a new TicketClass via
  # Production#assign_default_ticket_classes, so the column has to exist here
  # or auto-attached classes lose the zone filter entirely.
  def change
    add_column :default_ticket_classes, :zone_id, :string, limit: 2, null: false, default: '*'
  end
end
