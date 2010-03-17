class CreateTicketClasses < ActiveRecord::Migration
  def self.up
    begin 
      drop_table :ticket_classes
    rescue StandardError => e
    end
    create_table :ticket_classes do |t|
      t.string :class_code
      t.string :class_name
      t.float :ticket_price
      t.float :ticketing_fee
      t.boolean :web_visible
      t.string :ticket_type
      t.integer :minutes_before_show
      t.references :production

      t.timestamps
    end
  end

  def self.down
    drop_table :ticket_classes
  end
end
