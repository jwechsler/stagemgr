class Venue < ActiveRecord::Base
  attr_accessible :name, :ordinal_sort
  validates_presence_of :name, :ordinal_sort
  has_many :productions

  def now_playing(production_class)
    self.productions.select{|p| p.now_playing? && p.is_visible? && p.production_class == production_class}
  end

  def now_playing_or_next_up(production_class)
    prods = self.now_playing(production_class)
    if prods.empty? then
      future_prods = self.productions.select{|p| p.first_playing_date > Date.today && p.is_visible? && p.production_class == production_class}.sort { |p1,p2| p1.first_preview_at <=> p2.first_preview_at}
      prods = [future_prods.first] if !future_prods.empty?
    end
    prods
  end

  def <=>(venue)
    self.ordinal_sort <=> venue.ordinal_sort
  end
end
