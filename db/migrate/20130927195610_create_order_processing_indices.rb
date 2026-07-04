class CreateOrderProcessingIndices < ActiveRecord::Migration[4.2]
  def change
    add_index :payments, :membership_id
  end

  def down; end
end
