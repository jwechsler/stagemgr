class ChangeFileStoreNotesToText < ActiveRecord::Migration[6.1]
  def up
    change_column :file_stores, :notes, :text
  end

  def down
    change_column :file_stores, :notes, :string, limit: 255
  end
end
