class AddExcludeTheaterToFlexPass < ActiveRecord::Migration
  def self.up
    add_column  :flex_pass_offers,:exclude_theater,:boolean,{:default=>false, :null=>false}
  end

  def self.down
    remove_column :flex_pass_offers, :exclude_theater
  end
end
