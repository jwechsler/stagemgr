class FixMissingPaymentTypes < ActiveRecord::Migration[6.1]
  def up
    execute 'update payments set payment_type_id = 1 where payment_type_id is null'
  end

  def down; end
end
