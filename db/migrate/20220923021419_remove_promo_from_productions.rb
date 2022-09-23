class RemovePromoFromProductions < ActiveRecord::Migration[5.2]
  def change
    Production.all.each{|prod| prod.promo.analyze if prod.promo.attached?}
    remove_column :productions, :promo_file_name, :string 
    remove_column :productions, :promo_content_type, :string 
    remove_column :productions, :promo_file_size, :integer 
    remove_column :productions, :promo_updated_at, :datetime 
    
  end
end
