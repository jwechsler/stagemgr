class AddTreatAsFestivalPassToFlexPassOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :flex_pass_offers, :treat_as_festival_pass, :boolean
  end
end
