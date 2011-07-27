class AddPromoToProductions < ActiveRecord::Migration
  def self.up
    add_column :productions, :promo_file_name, :string
    add_column :productions, :promo_content_type, :string
    add_column :productions, :promo_file_size, :integer
    add_column :productions, :promo_updated_at, :datetime
  end

  def self.down
    remove_column :productions, :promo_updated_at
    remove_column :productions, :promo_file_size
    remove_column :productions, :promo_content_type
    remove_column :productions, :promo_file_name
  end
end
