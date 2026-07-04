class AddTicketingFeesToRateOfSales < ActiveRecord::Migration[6.1]
  def change
    # Isolated ticketing (facility) fee, mirroring gross_sales precision/scale.
    # Nullable: null means "not yet backfilled" (the analysis falls back to
    # gross_sales for those rows). The existing processing_fees column keeps
    # storing the combined ticketing+processing legacy figure for compatibility.
    add_column :rate_of_sales, :ticketing_fees, :decimal, precision: 8, scale: 2, null: true
  end
end
