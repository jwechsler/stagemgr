class CreateDefaultTicketClasses < ActiveRecord::Migration[4.2]
  def self.up
    create_table :default_ticket_classes do |t|
      t.string :class_code
      t.string :class_name
      t.string :description
      t.integer :minutes_before_show
      t.decimal :ticket_price,:precision=>6, :scale=>2
      t.string :ticket_type
      t.decimal :ticketing_fee, :precision=>6, :scale=>2
      t.boolean :web_visible
      t.timestamps
    end

  end

  def self.down
    drop_table :default_ticket_classes
  end
end
