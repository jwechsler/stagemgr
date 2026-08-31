class CreateResourcedTicketClasses < ActiveRecord::Migration[6.1]
  # A ResourcedTicketClass is a globally managed ticket class backed by a
  # limited pool of physical devices (captioning tablets, audio-description
  # receivers) shared across venues. It mirrors the ticket_classes column set
  # (minus production_id -- it is global) and adds the two pool attributes:
  # quantity (how many devices exist) and changeover_minutes (prep/return time
  # bracketing each performance).
  #
  # The resource materializes one shadow TicketClass per production in its
  # venues; those shadow rows carry the mirrored attributes so all existing
  # allocation/line-item/report machinery keeps working unchanged.
  def change
    create_table :resourced_ticket_classes do |t|
      t.string  :class_code, null: false
      t.string  :class_name
      t.string  :description
      t.string  :ticket_type
      t.integer :minutes_before_show
      t.boolean :web_visible
      t.boolean :auto_attach, default: true
      t.boolean :software_managed
      t.boolean :holds_seats, default: false
      t.boolean :assigns_seats, default: false
      t.boolean :show_in_pricing_range, default: true
      t.boolean :suppress_receipt, default: false
      t.boolean :hide_pricing
      t.boolean :complimentary, default: false
      t.boolean :exchangeable, default: false
      t.decimal :ticketing_fee, precision: 8, scale: 2, default: 0
      t.decimal :ticket_price, precision: 8, scale: 2, default: 0
      t.decimal :royalty_amount, precision: 8, scale: 2
      t.string  :zone_id, limit: 2, default: '*', null: false
      t.integer :quantity, null: false
      t.integer :changeover_minutes, null: false, default: 0

      t.timestamps
    end

    # Global namespace, like default_ticket_classes.class_code.
    add_index :resourced_ticket_classes, :class_code, unique: true
  end
end
