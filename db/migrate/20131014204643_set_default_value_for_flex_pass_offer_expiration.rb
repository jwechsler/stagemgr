class SetDefaultValueForFlexPassOfferExpiration < ActiveRecord::Migration[4.2]
  def up
    FlexPassOffer.where('months_till_expiration is null').each { |fpo|
      fpo.months_till_expiration = 12
      fpo.save!
    }
    change_column :flex_pass_offers, :months_till_expiration, :integer, :default => 12
  end

  def down
  end
end
