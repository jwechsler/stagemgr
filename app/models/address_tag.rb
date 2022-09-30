class AddressTag < ApplicationRecord

  EXTERNAL_ID = 'External ID' # Special tag for order matchups

  validates_presence_of :address

  belongs_to :theater, optional: true
  belongs_to :address, inverse_of: :address_tags

  def to_s
    "#{self.tag_label} = '#{self.tag_value}'"
  end

end
