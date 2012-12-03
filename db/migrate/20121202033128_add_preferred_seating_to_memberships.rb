class AddPreferredSeatingToMemberships < ActiveRecord::Migration
  def change
    add_column :memberships, :preferred_seating, :string, :default => Membership::BEST_AVAILABLE
  end
end
