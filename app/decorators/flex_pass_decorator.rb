class FlexPassDecorator < ApplicationDecorator
  delegate_all

  # Shown where a legacy pass lacks the value (no address, line item or date).
  MISSING = '—'.freeze

  def description
    "#{flex_pass.flex_pass_offer.name} [#{flex_pass.code}], #{flex_pass.uses_remaining} remaining. " + (flex_pass.available? ? "Expires #{flex_pass.expiration_date}" : h.raw("<span class='label error'>Expired</span>"))
  end

  # Datatable cells (admin flex pass offer show page): link_to/content_tag
  # only, since h.render returns "" inside datatable JSON.
  # The order's address, not the pass's own: flex_passes.address_id can point
  # at an address row deleted since the sale, while orders.address_id is kept
  # current. The pass's address is only a fallback for passes with no line item.
  def patron_link
    address = object.flex_pass_line_item&.order&.address || object.address
    return MISSING if address.nil?

    h.link_to(address.full_name, h.admin_address_path(address))
  end

  def order_link
    order_id = object.flex_pass_line_item&.order_id
    return MISSING if order_id.nil?

    h.link_to("Order #{order_id}", h.admin_flex_pass_order_path(order_id))
  end

  # Flags a pass whose order hasn't reached Fulfilled; blank otherwise.
  def fulfillment_label
    order = object.flex_pass_line_item&.order
    return '' if order.nil? || order.fulfilled?

    h.ui_label('Unfulfilled', variant: :warning)
  end

  def purchased_on
    object.created_at&.to_date&.to_formatted_s(:numeric_date) || MISSING
  end

  def expires_on
    object.expiration_date&.to_formatted_s(:numeric_date) || MISSING
  end
end
