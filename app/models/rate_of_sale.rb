class RateOfSale < ApplicationRecord
  belongs_to :production
  has_one :theater, through: :production

  validates :day_of_sale, presence: true
  validates :production, presence: true
  validates :total_single_tickets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_complimentary_tickets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gross_sales, numericality: { greater_than_or_equal_to: 0 }
  validates :processing_fees, numericality: { greater_than_or_equal_to: 0 }

end
