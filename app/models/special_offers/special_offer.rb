class SpecialOffer < ActiveRecord::Base
  validates_presence_of :type, :code
  validates_numericality_of :amount, :null=>false

  OFFER_STATUSES = (
    ACTIVE, INACTIVE, EXPIRED =
        "Active", "Inactive", "Expired")

  attr_accessor :limiting_model_type
  attr_accessor :limiting_id
  #models to limit this special offer to
  belongs_to :theater
  belongs_to :production
  belongs_to :performance

  validate :find_limiting_object

  def find_limiting_object
    t, i = limiting_model_type, limiting_id
    self.theater = nil
    self.production = nil
    self.performance = nil
    return if (t.nil? || t.blank?) && (i.nil? || i.blank?)
    limiting_object = case t
    when 'Theater'
      (self.theater = Theater.find_by_id(i)) || 
        errors.add_to_base("Can't find Theater with id: #{i}")
    when 'Production'
      (self.production = Production.find_by_production_code(i)) || 
        errors.add_to_base("Can't find Production with code: #{i}")
    when 'Performance' 
      (self.performance = Performance.find_by_performance_code(i)) ||
        errors.add_to_base("Can't find Performance with code: #{i}")
    when '', nil
      errors.add_to_base("You didn't pick the type but you enterd the id of: #{i}")
    else
      errors.add_to_base('You tried to use an unknown type')
      nil
    end
  end
  
  def limiting_model_type
    @limiting_model_type||=case
    when !self.theater.nil?
      'Theater'
    when !self.production.nil?
      'Production'
    when !self.performance.nil?
      'Performance'
    else
      nil
    end
  end
  
  def limiting_id
    @limiting_id ||= 
      self.theater_id ||
      self.production.nil_or.production_code ||
      self.performance.nil_or.performance_code
  end
  
  def applicable_line_items(order)
    look_for = ticket_class_code.nil? ? '' : self.ticket_class_code

    return order.ticket_line_items.select{ |li| li.ticket_class.class_code.starts_with?(look_for)}
  end
  
  
  def calculate_discount(order)
    raise 'Inimplemented'
  end

  def create_code(prefix = '', size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.code.nil? || !FlexPass.find_by_code(self.code).nil?
      self.code = (0...size).map{ charset.to_a[rand(charset.size)] }.join
    end
    self.code = prefix + self.code
  end

  def self.find_by_order(order)
    perf_id = order.performance.id
    prod_id = order.performance.production.id
    theater_id = order.performance.production.theater.id
    offers = SpecialOffer.all(
                               :conditions => ["trim(lower(code)) = trim(lower(?)) and (performance_id = ? or production_id = ? or theater_id = ? or (performance_id is null and production_id is null and theater_id is null)) and (auto_expire is null or auto_expire >= ?)",
                               order.special_offer_code,
                               perf_id,
                               prod_id,
                               theater_id,
                               Time.now],
                               :order=>"performance_id desc, production_id desc, theater_id desc")
    offers.select{|o|
      (o.ticket_class_code.blank? || order.ticket_line_items.select{|li|
        li.ticket_class.class_code.starts_with?(o.ticket_class_code)}.size > 0) &&
          (o.number_of_uses.blank? || o.number_of_uses > 0)
    }.first

  end

  def redeem_one_use!
    self.number_of_uses -= 1 if !self.number_of_uses.blank? && self.number_of_uses >= 0
    self.save!
  end
end
