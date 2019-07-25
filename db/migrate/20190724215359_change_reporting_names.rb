class ChangeReportingNames < ActiveRecord::Migration
  def change
    rename_column :payment_types, :report_as_sales_income, :report_as_sales_collected
    rename_column :payment_types, :report_as_production_income, :report_as_production_revenue
  end
end
