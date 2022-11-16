class AddMyemmaSourceGroup < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :myemma_attendee_group, :string
  end

  def self.down
    remove_column :productions, :myemma_attendee_group
  end
end
