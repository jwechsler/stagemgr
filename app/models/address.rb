class Address < ActiveRecord::Base
  validates_presence_of :line1, :city, :state, :zipcode
end
