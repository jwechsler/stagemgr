class AddExtendedDetailToDefaultTicketTypes < ActiveRecord::Migration
  def change
    add_column :default_ticket_classes, :purchase_page_annotation, :string
    add_column :default_ticket_classes, :purchase_email_annotation, :text
    add_column :ticket_classes, :purchase_page_annotation, :string
    add_column :ticket_classes, :purchase_email_annotation, :text
  end
end
