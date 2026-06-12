class RemoveHashFromFileStores < ActiveRecord::Migration[6.1]
  def change
    remove_index :file_stores, :hash, if_exists: true
    remove_column :file_stores, :hash, :string
  end
end
