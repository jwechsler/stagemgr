class CreateServiceItemTemplates < ActiveRecord::Migration
  def change
    create_table :service_item_templates do |t|
      t.string :name
      t.string :description, :null=>false
      t.float :amount
      t.float :facility_fee
      t.timestamps null: false
      t.index :name, unique: true
    end

  end
end
