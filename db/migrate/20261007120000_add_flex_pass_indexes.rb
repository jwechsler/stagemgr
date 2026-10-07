class AddFlexPassIndexes < ActiveRecord::Migration[6.1]
  # FlexPass.outstanding sums each pass's redeemed tickets from payments by
  # flex_pass_id (FlexPass::TICKETS_REDEEMED_SQL), and the offer index's
  # outstanding filter looks passes up by offer; without these indexes every
  # pass scans payments and every offer scans flex_passes.
  def change
    add_index :payments, :flex_pass_id
    add_index :flex_passes, :flex_pass_offer_id
  end
end
