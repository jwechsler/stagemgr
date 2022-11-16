class AddProcessorIdToAddress < ActiveRecord::Migration[4.2]
  def change
    add_column :addresses, :processor_id, :string
  end
end
