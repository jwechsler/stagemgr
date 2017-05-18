class AddCustomLabelToProductions < ActiveRecord::Migration
  def change
    add_column :productions, :custom_label, :string
  end
end
