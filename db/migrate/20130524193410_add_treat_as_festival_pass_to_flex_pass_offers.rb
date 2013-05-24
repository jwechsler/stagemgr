class AddTreatAsFestivalPassToFlexPassOffers < ActiveRecord::Migration
  def change
    add_column :flex_pass_offers, :treat_as_festival_pass, :boolean
  end
end
