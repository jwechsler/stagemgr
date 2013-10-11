class CreateFileStores < ActiveRecord::Migration
  def change
    create_table :file_stores do |t|
      t.integer :user_id
      t.string :name
      t.string :hash
      t.string :worker

      t.timestamps
    end
    add_index :file_stores, :hash
    add_index :file_stores, :user_id
  end

end
