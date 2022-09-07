class AddFormatToFileStore < ActiveRecord::Migration[4.2]
  def change
    add_column :file_stores, :format, :string
  end
end
