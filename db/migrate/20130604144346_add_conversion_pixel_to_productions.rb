class AddConversionPixelToProductions < ActiveRecord::Migration[4.2]
  def change
    add_column :productions, :conversion_pixel_code, :text
  end
end
