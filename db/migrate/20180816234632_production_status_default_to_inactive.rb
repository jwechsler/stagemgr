class ProductionStatusDefaultToInactive < ActiveRecord::Migration[4.2]
  def change
    change_column_default(
      :productions,
      :status,
      from: nil,
      to: Production::INACTIVE
    )
  end
end
