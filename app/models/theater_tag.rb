class TheaterTag < ApplicationRecord
  belongs_to :theater, inverse_of: :theater_tags

  before_validation { self.name = name.to_s.strip.presence }
  validates :name, presence: true
  validates :name, uniqueness: { scope: :theater_id, case_sensitive: false }

  def to_s
    name
  end
end
