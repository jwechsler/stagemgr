class AddAutofulfillPerformanceCodesToFlexPassOffers < ActiveRecord::Migration[6.1]
  def change
    add_column :flex_pass_offers, :autofulfill_performance_codes, :text
  end
end
