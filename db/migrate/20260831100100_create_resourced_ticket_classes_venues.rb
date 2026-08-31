class CreateResourcedTicketClassesVenues < ActiveRecord::Migration[6.1]
  # A resource is scoped to a set of venues (physical spaces). It constrains
  # performances of productions whose venue_id falls in that set.
  def change
    create_join_table :resourced_ticket_classes, :venues do |t|
      t.index %i[resourced_ticket_class_id venue_id],
              unique: true, name: 'index_rtc_venues_on_rtc_and_venue'
    end
  end
end
