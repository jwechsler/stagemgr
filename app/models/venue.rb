class Venue < ActiveRecord::Base
  attr_accessible :name, :ordinal_sort
  validates_presence_of :name, :ordinal_sort
  has_many :productions

  def now_playing(production_class)
    self.productions.select{|p| p.first_preview_at <= Date.today && p.closing_at >= Date.today && p.production_class = production_class}
  end

  def <=>(venue)
    self.ordinal_sort <=> venue.ordinal_sort
  end
end
