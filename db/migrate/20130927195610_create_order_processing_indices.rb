class CreateOrderProcessingIndices < ActiveRecord::Migration
  def change
    add_index :payments, :membership_id
  end

  def down
  end
end
