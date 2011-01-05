class CreateTheatersUsers < ActiveRecord::Migration
  def self.up
    create_table :theaters_users, :id => false do |t|
      t.references :theater
      t.references :user
    end
  end

  def self.down
    drop_table :theaters_users
  end
end
