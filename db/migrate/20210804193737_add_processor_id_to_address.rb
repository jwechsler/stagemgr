class AddProcessorIdToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :processor_id, :string
  end
end
