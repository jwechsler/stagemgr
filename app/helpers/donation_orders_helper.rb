module DonationOrdersHelper

  def donation_order_common_params
    common_params + [:campaign, donation_line_items_attributes: [:amount, :donation_level]]
  end

end