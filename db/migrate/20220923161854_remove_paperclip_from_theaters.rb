class RemovePaperclipFromTheaters < ActiveRecord::Migration[5.2]
  def change
    Theater.all.each { |t| t.logo.analyze if t.logo.attached? }
    remove_column :theaters, :logo_file_name, :string
    remove_column :theaters, :logo_content_type, :string
    remove_column :theaters, :logo_file_size, :integer
    remove_column :theaters, :logo_updated_at, :datetime
  end
end
