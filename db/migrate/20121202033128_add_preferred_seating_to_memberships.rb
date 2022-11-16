class AddPreferredSeatingToMemberships < ActiveRecord::Migration[4.2]
  def change
    add_column :memberships, :preferred_seating, :string, :default => Membership::BEST_AVAILABLE
  end
end
