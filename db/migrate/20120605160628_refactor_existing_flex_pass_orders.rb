class RefactorExistingFlexPassOrders < ActiveRecord::Migration[4.2]
  def self.up
    execute "update orders set type = 'FlexPassOrder' where id in (select order_id from line_items where type = 'FlexPassLineItem')"
  end

  def self.down
    execute "update orders set type = 'Order' where id in (select order_id from line_items where type = 'FlexPassLineItem')"
  end
end
