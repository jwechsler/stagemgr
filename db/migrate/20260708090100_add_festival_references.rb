class AddFestivalReferences < ActiveRecord::Migration[6.1]
  def change
    add_column :productions, :festival_id, :bigint
    add_index :productions, :festival_id
    add_foreign_key :productions, :festivals, on_delete: :nullify

    add_column :flex_pass_offers, :festival_id, :bigint
    add_index :flex_pass_offers, :festival_id
    add_foreign_key :flex_pass_offers, :festivals, on_delete: :nullify

    add_column :membership_offers, :max_festival_tickets_in_advance, :integer
  end
end
