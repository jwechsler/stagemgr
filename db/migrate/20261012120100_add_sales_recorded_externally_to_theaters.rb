class AddSalesRecordedExternallyToTheaters < ActiveRecord::Migration[6.1]
  # Tickets for such a theater are keyed in from an outside system, so their
  # order dates are not real purchase dates. The advance-sales analysis leaves
  # these theaters out by default.
  def change
    add_column :theaters, :sales_recorded_externally, :boolean, default: false, null: false
  end
end
