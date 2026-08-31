class AddAnnotationsToResourcedTicketClasses < ActiveRecord::Migration[6.1]
  # The purchase annotations belong on the global resource like every other
  # ticket-class attribute: a captioning-tablet class needs the same "pick up
  # your device at the box office" copy on every production it appears in.
  # Types mirror ticket_classes (string page annotation, mediumtext email
  # annotation) so ResourcedTicketClass#shadow_attributes copies them verbatim.
  def change
    add_column :resourced_ticket_classes, :purchase_page_annotation, :string
    add_column :resourced_ticket_classes, :purchase_email_annotation, :text, limit: 16.megabytes - 1
  end
end
