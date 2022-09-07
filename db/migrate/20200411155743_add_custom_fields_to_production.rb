class AddCustomFieldsToProduction < ActiveRecord::Migration[4.2]
  def change
    add_column :productions, :custom1, :string
    add_column :productions, :custom2, :string
  end
end
