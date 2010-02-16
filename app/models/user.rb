class User < ActiveRecord::Base
  has_and_belongs_to_many :user_groups

  acts_as_authentic do |c|
    #c.my_config_option = my_value
  end

  def has_role(*args);end
  def remove_role(*args);end
  
end
