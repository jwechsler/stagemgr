class AddAdmissionToTicketClasses < ActiveRecord::Migration[6.1]
  # How a ticket class's patrons attend: in_person (default), virtual
  # (streaming) or other. Only in_person tickets print, and patron emails
  # adapt their visit/pickup copy to it. resourced_ticket_classes is
  # deliberately left out: shadow rows take the in_person default, so
  # equipment rentals keep printing.
  def change
    add_column :ticket_classes, :admission, :string, limit: 16, default: 'in_person', null: false
    add_column :default_ticket_classes, :admission, :string, limit: 16, default: 'in_person', null: false
  end
end
