class RateOfSale < Metric

  belongs_to :production
  has_one :theater, through: :production

  validates :day_of_sale, presence: true
  validates :production, presence: true
  validates :total_single_tickets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_complimentary_tickets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gross_sales, numericality: { greater_than_or_equal_to: 0 }
  validates :processing_fees, presence: true

  def self.export_columns
    {day_of_sale: "Date", production: "Production", total_single_tickets: "Tickets", 
      total_complimentary_tickets: "Comps", gross_sales: "Total", processing_fees: "Fees"}
  end

  def self.export_records
    eight_days_ago = Date.yesterday - 7.days
    yesterday = Date.yesterday
    RateOfSale.where(day_of_sale: eight_days_ago..yesterday)
  end

end
