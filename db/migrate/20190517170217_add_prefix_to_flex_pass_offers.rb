class AddPrefixToFlexPassOffers < ActiveRecord::Migration[4.2]
  def change
    add_column :flex_pass_offers, :code_prefix, :string
  end
end
