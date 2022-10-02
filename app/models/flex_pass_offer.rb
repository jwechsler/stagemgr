class FlexPassOffer < ApplicationRecord

  belongs_to :theater, optional: true, inverse_of: :flex_pass_offers
  has_one :production, inverse_of: :flex_pass_offers
  has_many :flex_passes, inverse_of: :flex_pass_offer
  has_many :flex_pass_line_items, inverse_of: :flex_pass_offer
  
  validates_numericality_of :price, :number_of_tickets, :null=>false
  validates_presence_of :months_till_expiration
  validates_presence_of :name, :price, :number_of_tickets, :use_ticket_class_code

  before_validation :set_public_sale_by_active

  private
  def set_public_sale_by_active
    self.active ||= self.on_sale_to_public?
  end
end
