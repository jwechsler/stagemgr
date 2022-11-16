class RenameFileNameToNotesInFileStore < ActiveRecord::Migration[4.2]
  def up
    rename_column :file_stores, :name, :notes
  end

  def down
    rename_column :file_stores, :notes, :name
  end
end
