class FixDetachedFlexPasses < ActiveRecord::Migration[6.1]
  def change
    flex_passes = FlexPass.all
    flex_passes.each do |fp|
      fp.address = fp.flex_pass_line_item.order.address unless fp.flex_pass_line_item.nil?
      fp.save! if fp.address_id_changed?
    end
    execute ("delete from flex_passes where (address_id not in (select id from addresses)) and (flex_pass_line_item_id not in (select id from line_items))")
    remove_column :flex_passes, :order_id, :integer
  end
end
