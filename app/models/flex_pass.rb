class FlexPass < ApplicationRecord
  belongs_to :address, inverse_of: :flex_passes, optional: true 
  belongs_to :flex_pass_offer, inverse_of: :flex_passes
  belongs_to :flex_pass_line_item, inverse_of: :flex_pass
  
  has_many :flex_pass_payments, inverse_of: :flex_pass
  before_create :set_expiration_date
  after_create :queue_expiration
  before_destroy :has_no_placed_orders?
  
  validates_presence_of :expiration_date, :flex_pass_offer, :flex_pass_line_item, :order, :code
  validates :address, presence: true, unless: -> { address.blank? }
  
  before_validation :create_code, :on => :create

  delegate :number_of_tickets, :to => :flex_pass_offer
  delegate :order, to: :flex_pass_line_item

  # Generates a random string from a set of easily readable characters
  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.code.nil? || !FlexPass.find_by_code(self.code).nil?
      self.code = (self.flex_pass_offer.code_prefix.blank? ? "" : self.flex_pass_offer.code_prefix) + (0...size).map{ charset.to_a[rand(charset.size)] }.join
    end
  end

  def uses_remaining
    used = FlexPassPayment.where("flex_pass_id = ?", self.id).sum(:number_of_tickets)
    self.flex_pass_offer.number_of_tickets - used
  end

  def available?
    self.uses_remaining > 0 && self.active?
  end

  def set_expiration_date
    self.expiration_date = Time.now + flex_pass_offer.months_till_expiration.months
  end

  def expired?
    self.expiration_date < Date.today
  end

  def used_on_orders
    self.flex_pass_payments.map { |fpp| fpp.order}
  end

  def queue_expiration
    Resque.enqueue_in(flex_pass_offer.months_till_expiration.months, ExpireFlexPass, self.id)
  end

  def self.check_expirations
    FlexPass.find_all_by_active(true).each {|flex_pass|
      if flex_pass.expiration_date <= Date.today || flex_pass.uses_remaining == 0
        flex_pass.active=false
        flex_pass.save!
      end
    }
  end

  def self.fix_mangled_passes
    passes = FlexPass.all
    passes.select{|p| p.flex_pass_line_item.nil? }.each{|p| p.destroy}
    passes = FlexPass.all
    passes.each { |p|
      p.order = p.flex_pass_line_item.order
      p.address = p.order.address
      p.expiration_date = p.created_at.to_date + p.flex_pass_offer.months_till_expiration.months
      p.save!
     }; ""
  end

  def has_placed_orders?
    FlexPassPayment.where(flex_pass_id: self.id).count > 0
  end

  #
  # get all orders placed with this flexpass
  #
  def ticket_orders 
    orders = TicketOrder.joins(:payments).where("payments.type = 'FlexPassPayment' and flex_pass_id = :fp_id", {fp_id: self.id})
  end

  def upcoming_ticket_orders
    self.ticket_orders.finalized.joins(:performance).where("performance_date >= ?", Date.today)
  end

  def attended_ticket_orders
    ticket_orders.attending.joins(:performance).where("performance_date < ?", Date.today)
  end

  def has_no_placed_orders?
    !self.has_placed_orders?
  end

  def has_no_outstanding_orders?
    FlexPassPayment.joins(:order).where(flex_pass_id: self.id).count > 0
  end

end
