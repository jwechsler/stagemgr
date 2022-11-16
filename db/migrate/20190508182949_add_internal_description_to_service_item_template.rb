class AddInternalDescriptionToServiceItemTemplate < ActiveRecord::Migration[4.2]
  def change
    add_column :service_item_templates, :internal_description, :string
    add_column :line_items, :internal_description, :string
    add_column :service_item_templates, :user_selectable, :boolean, default: true
  end
end
