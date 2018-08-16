class ProductionStatusDefaultToInactive < ActiveRecord::Migration
  def change
    change_column_default(
      :productions,
      :status,
      :from=>nil,
      :to=>Production::INACTIVE
    )
  end
end
