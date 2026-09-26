class AddAdmissionToTicketClasses < ActiveRecord::Migration[6.1]
  # How a ticket class's patrons attend: in_person (default), virtual
  # (streaming) or other. Only in_person tickets print, and patron emails adapt
  # their visit/pickup copy to it. resourced_ticket_classes gets the column in
  # a later migration (20260926100000).
  def change
    add_column :ticket_classes, :admission, :string, limit: 16, default: 'in_person', null: false
    add_column :default_ticket_classes, :admission, :string, limit: 16, default: 'in_person', null: false
  end
end
