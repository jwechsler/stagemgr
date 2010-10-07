class FlexPass < ActiveRecord::Base
  belongs_to :address
  belongs_to :flex_pass_offer
  belongs_to :flex_pass_line_item
  belongs_to :order
  
  validates_presence_of :address, :flex_pass_offer, :flex_pass_line_item, :order, :code
  
  before_validation_on_create :create_code
  
  # Generates a random string from a set of easily readable characters
  def create_code(size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.code.nil? || !FlexPass.find_by_code(self.code).nil?
      self.code = (0...size).map{ charset.to_a[rand(charset.size)] }.join
    end
  end
  
end
