class AddressTag < ApplicationRecord
  EXTERNAL_ID = 'External ID' # Special tag for order matchups

  validates :address, presence: true

  belongs_to :theater, optional: true
  belongs_to :address, inverse_of: :address_tags

  def to_s
    "#{tag_label} = '#{tag_value}'"
  end
end
