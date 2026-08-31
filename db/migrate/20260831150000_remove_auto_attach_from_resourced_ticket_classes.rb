class RemoveAutoAttachFromResourcedTicketClasses < ActiveRecord::Migration[6.1]
  # Auto-attach is deliberately not a resource concept. Toggling it on a global
  # resource would force-reactivate allocations on EVERY outstanding performance
  # across every production in its venues (Performance#populate_ticket_class_allocations
  # re-forces available=true for auto_attach classes on each save), silently
  # clobbering per-performance curation -- e.g. captioning tablets that only go
  # on sale after technical staff has cued the show. Resourced allocations are
  # therefore always created inactive and enabled per performance by staff.
  def change
    remove_column :resourced_ticket_classes, :auto_attach, :boolean, default: true
  end
end
