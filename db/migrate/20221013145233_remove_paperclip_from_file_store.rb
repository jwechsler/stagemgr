class RemovePaperclipFromFileStore < ActiveRecord::Migration[6.1]
  def change
    remove_column :file_stores, :hash
    remove_column :file_stores, :data_file_name, :string  
    remove_column :file_stores, :data_content_type, :string 
    remove_column :file_stores, :data_file_size, :integer 
    remove_column :file_stores, :data_updated_at, :datetime   
  end
end
