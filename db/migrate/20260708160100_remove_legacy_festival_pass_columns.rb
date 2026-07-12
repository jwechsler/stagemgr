# The pre-Festival festival-pass mechanism (flagging an offer as a festival
# pass and grouping productions by flex_pass_offer_id) is superseded by the
# Festival model: productions.festival_id + flex_pass_offers.festival_id.
# 20260708090200_create_festivals_from_festival_pass_offers migrated the data.
class RemoveLegacyFestivalPassColumns < ActiveRecord::Migration[6.1]
  def change
    remove_column :flex_pass_offers, :treat_as_festival_pass, :boolean
    remove_column :productions, :flex_pass_offer_id, :integer
  end
end
