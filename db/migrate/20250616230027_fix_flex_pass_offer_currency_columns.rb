class FixFlexPassOfferCurrencyColumns < ActiveRecord::Migration[6.1]
  def change
    # Change price from float to decimal
    change_column :flex_pass_offers, :price, :decimal, precision: 8, scale: 2, null: false
    
    # Change payout fields to have proper precision and scale
    change_column :flex_pass_offers, :facility_fee, :decimal, precision: 8, scale: 2
    change_column :flex_pass_offers, :spiff, :decimal, precision: 8, scale: 2
    change_column :flex_pass_offers, :flat_payout, :decimal, precision: 8, scale: 2
  end
end
