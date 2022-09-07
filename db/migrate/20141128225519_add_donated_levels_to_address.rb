class AddDonatedLevelsToAddress < ActiveRecord::Migration[4.2]
  def change
    add_money :addresses, :donated_this_year
    add_money :addresses, :donated_last_year
    add_money :addresses, :donated_last_n_days
  end
end
