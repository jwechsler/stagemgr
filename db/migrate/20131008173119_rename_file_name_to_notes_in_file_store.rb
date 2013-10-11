class RenameFileNameToNotesInFileStore < ActiveRecord::Migration
  def up
    rename_column :file_stores, :name, :notes
  end

  def down
    rename_column :file_stores, :notes, :name
  end
end
