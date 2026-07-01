module FlexPassOrdersHelper
  def common_flex_pass_order_params
    common_params + [{ flex_pass_line_item_attributes: %i[id ticket_count flex_pass_offer_id] }]
  end
end
