class AddShowLogo < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :logo_url, :string
  end

  def self.down
    remove_column :productions, :logo_url
  end
end
