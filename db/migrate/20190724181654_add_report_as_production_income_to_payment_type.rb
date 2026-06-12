class AddReportAsProductionIncomeToPaymentType < ActiveRecord::Migration[4.2]
  def change
    add_column :payment_types, :report_as_production_income, :boolean, :default => true
  end
end
