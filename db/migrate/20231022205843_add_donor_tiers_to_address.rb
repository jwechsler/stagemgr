class AddDonorTiersToAddress < ActiveRecord::Migration[6.1]
  def change
    remove_monetize :addresses, :donated_this_year
    remove_monetize :addresses, :donated_last_year
    remove_monetize :addresses, :donated_last_n_days
    add_column    :addresses, :donor_tier_for_last_fiscal_year, :string
    add_column    :addresses, :donor_tier_for_current_fiscal_year, :string
    add_column    :addresses, :donor_tier_updated_on, :date
  end
end
