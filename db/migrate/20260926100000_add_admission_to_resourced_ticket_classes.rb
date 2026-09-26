class AddAdmissionToResourcedTicketClasses < ActiveRecord::Migration[6.1]
  # Resourced ticket classes (shared equipment such as captioning tablets)
  # carry an admission mode too, so a resource can be 'other': a reservation
  # that prints no ticket and never counts toward the patron's ticket total.
  # ResourcedTicketClass#shadow_attributes copies it onto every shadow
  # TicketClass row. The in_person default keeps existing resources printing.
  def change
    add_column :resourced_ticket_classes, :admission, :string, limit: 16, default: 'in_person', null: false
  end
end
