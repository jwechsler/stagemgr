class AddZoneIdToTicketClasses < ActiveRecord::Migration[6.1]
  # Zone filter for zoned pricing: a class is sellable for a seat iff
  # zone_id == '*' (wildcard, the default) or zone_id == seat.zone.
  # Existing classes get '*' so every legacy show keeps its current behavior.
  def change
    add_column :ticket_classes, :zone_id, :string, limit: 2, null: false, default: '*'
  end
end
