class AddReportAsSalesIncomeToPaymentType < ActiveRecord::Migration
  def change
    add_column :payment_types, :report_as_sales_income, :boolean, :default=>true
  end
end
