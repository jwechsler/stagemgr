class InvalidateDisassociatedFlexPasses < ActiveRecord::Migration
  def up
    execute "update flex_passes set active=false where flex_passes.order_id not in (select id from orders where type = 'FlexPassOrder')
    or flex_passes.flex_pass_line_item_id not in (select id from line_items where type = 'FlexPassLineItem')"
  end

  def down
  end
end
