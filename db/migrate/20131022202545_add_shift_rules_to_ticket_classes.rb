class AddShiftRulesToTicketClasses < ActiveRecord::Migration[4.2]
  def change
    add_column :ticket_class_allocations, :shiftable, :boolean, default: false
    add_column :ticket_class_allocations, :shift_to_code, :string
    add_column :ticket_class_allocations, :shift_days_before_performance, :integer
    add_column :ticket_class_allocations, :shift_when_capacity_over, :integer
  end
end
