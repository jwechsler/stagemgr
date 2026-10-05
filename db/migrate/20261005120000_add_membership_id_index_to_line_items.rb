class AddMembershipIdIndexToLineItems < ActiveRecord::Migration[6.1]
  # Membership reports look up each membership's purchase-order payments
  # through line_items.membership_id (MembershipMetrics::PAID_THROUGH_SQL),
  # once per membership; without an index every lookup scans line_items.
  def change
    add_index :line_items, :membership_id
  end
end
