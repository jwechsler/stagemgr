class CreateAddressTags < ActiveRecord::Migration[4.2]
  def change
    create_table :address_tags do |t|
      t.string :tag_label
      t.string :tag_value

      t.timestamps
    end
    add_reference :address_tags, :theater, index: true, on_delete: :cascade
    add_reference :address_tags, :address, index: true, on_delete: :cascade
  end
end
