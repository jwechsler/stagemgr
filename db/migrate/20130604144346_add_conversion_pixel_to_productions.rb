class AddConversionPixelToProductions < ActiveRecord::Migration
  def change
    add_column :productions, :conversion_pixel_code, :text
  end
end
