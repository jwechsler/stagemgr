class AddSuppressForPassPaymentsToServiceItemTemplate < ActiveRecord::Migration
  def change
    add_column :service_item_templates, :suppress_for_pass_payments, :boolean, default: false
  end
end
