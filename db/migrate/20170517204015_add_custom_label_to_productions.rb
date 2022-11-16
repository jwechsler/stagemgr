class AddCustomLabelToProductions < ActiveRecord::Migration[4.2]
  def change
    add_column :productions, :custom_label, :string
  end
end
