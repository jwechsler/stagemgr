class AddressTag < ActiveRecord::Base
  validates_presence_of :address

  belongs_to :theater
  belongs_to :address

  def to_s
    "#{self.tag_label} = '#{self.tag_value}'"
  end


end
