class User < ActiveRecord::Base
  has_and_belongs_to_many :theaters #, :as => :owned_theaters

  acts_as_authentic do |c|
    #c.my_config_option = my_value
  end
  
  before_validation :set_defaults, :on => :create
  
  def set_defaults
    self.is_administrator = false if self.is_administrator.nil?
    self.is_box_office_user = false if self.is_box_office_user.nil?
    true
  end

end
