class FlexPass < ActiveRecord::Base
  belongs_to :address
  belongs_to :flex_pass_offer
  belongs_to :flex_pass_line_item
  belongs_to :order
  has_many :flex_pass_payments
  before_create :set_expiration_date
  after_create :queue_expiration

  validates_presence_of :address, :flex_pass_offer, :flex_pass_line_item, :order, :code

  before_validation :create_code, :on => :create

  delegate :number_of_tickets, :to => :flex_pass_offer

  # Generates a random string from a set of easily readable characters
  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.code.nil? || !FlexPass.find_by_code(self.code).nil?
      self.code = (0...size).map{ charset.to_a[rand(charset.size)] }.join
    end
  end

  def uses_remaining
    used = FlexPassPayment.sum(:number_of_tickets,:conditions=>["flex_pass_id = ?", self.id])
    self.flex_pass_offer.number_of_tickets - used
  end

  def available?
    self.uses_remaining > 0 && self.active?
  end

  def set_expiration_date
    self.expiration_date = Time.now + flex_pass_offer.months_till_expiration
  end

  def queue_expiration
    Resque.enqueue_in(flex_pass_offer.months_till_expiration.months, ExpireFlexPass, self.id)
  end

  def self.check_expirations
    FlexPass.find_all_by_active(true).each {|flex_pass|
      if flex_pass.expiration_date <= Date.today || flex_pass.uses_remaining == 0
        flex_pass.active=false
        flex_pass.save
      end
    }
  end

end
