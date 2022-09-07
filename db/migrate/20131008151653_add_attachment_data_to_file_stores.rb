class AddAttachmentDataToFileStores < ActiveRecord::Migration[4.2]
  def self.up
    change_table :file_stores do |t|
      t.has_attached_file :data
    end
  end

  def self.down
    drop_attached_file :file_stores, :data
  end
end
