class FlexPassOffer < ApplicationRecord

  belongs_to :theater, optional: true
  validates_numericality_of :price, :number_of_tickets, :null=>false
  validates_presence_of :months_till_expiration
  has_many :flex_passes
  validates_presence_of :name, :price, :number_of_tickets, :use_ticket_class_code
  has_one :production
  before_validation :set_public_sale_by_active

  private
  def set_public_sale_by_active
    self.active ||= self.on_sale_to_public?
  end
end
