# Orders paid for in whole or in part by one membership: the address page's
# order history (AddressesOrdersDatatable), narrowed to the orders carrying a
# MembershipPayment for this membership, plus the amount the membership paid.
class MembershipRedemptionsDatatable < AddressesOrdersDatatable
  def view_columns
    @view_columns ||= super.merge(membership_paid: { searchable: false, orderable: false })
  end

  def data
    paid = membership_paid_by_order(records.map(&:id))
    super.map { |row| row.merge(membership_paid: ActiveSupport::NumberHelper.number_to_currency(paid.fetch(row[:DT_RowID], 0))) }
  end

  # Exchanged and refunded orders stay listed (their status says so). A
  # refund's reversal nets the membership's share to zero; an exchange's
  # offset is an ExchangePayment, so the exchanged order keeps its original
  # share and the replacement order is listed separately.
  def get_raw_records
    Order.allowed_for(current_user).where(id: redemptions.select(:order_id))
  end

  def membership
    @membership ||= options[:membership]
  end

  private

  def redemptions
    MembershipPayment.where(membership_id: membership.id)
  end

  def membership_paid_by_order(order_ids)
    redemptions.where(order_id: order_ids).reorder(nil).group(:order_id).sum(:amount)
  end
end
