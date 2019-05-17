class AddPrefixToFlexPassOffers < ActiveRecord::Migration
  def change
    add_column :flex_pass_offers, :code_prefix, :string
  end
end
