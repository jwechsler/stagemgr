class SetDefaultValueForFlexPassOfferExpiration < ActiveRecord::Migration[4.2]
  def up
    FlexPassOffer.where(months_till_expiration: nil).each do |fpo|
      fpo.months_till_expiration = 12
      fpo.save!
    end
    change_column :flex_pass_offers, :months_till_expiration, :integer, default: 12
  end

  def down; end
end
