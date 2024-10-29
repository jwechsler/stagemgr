class SetDefaultForBooleanFieldInAddresses < ActiveRecord::Migration[6.1]
  def up
    # Step 1: Update all existing NULL values to false
    Address.where(placeholder: nil).update_all(placeholder: false)

    # Step 2: Change the column default to false
    change_column_default :addresses, :placeholder, from: nil, to: false
  end

  def down
    # Revert the default to nil if you want to roll back
    change_column_default :addresses, :placeholder, from: false, to: nil
  end
end
