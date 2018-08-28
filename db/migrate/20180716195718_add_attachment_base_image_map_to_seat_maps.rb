class AddAttachmentBaseImageMapToSeatMaps < ActiveRecord::Migration
  def self.up
    change_table :seat_maps do |t|
      t.attachment :base_image_map
    end
  end

  def self.down
    remove_attachment :seat_maps, :base_image_map
  end
end
