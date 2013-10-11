class AddFormatToFileStore < ActiveRecord::Migration
  def change
    add_column :file_stores, :format, :string
  end
end
