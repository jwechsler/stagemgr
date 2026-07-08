class Venue < ApplicationRecord
  validates :name, :ordinal_sort, presence: true
  has_many :productions, inverse_of: :venue
  has_many :seat_maps, inverse_of: :venue

  def now_playing(production_class, through = nil)
    productions.select { |p| p.now_playing?(through) && p.visible? && p.production_class == production_class }
  end

  # exclude_festival skips shows that render inside a festival block
  # (Production#festival_grouped?); a festival's lone remaining show still
  # counts as a regular production and is never skipped.
  def now_playing_or_next_up(production_class, through = nil, exclude_festival: false)
    prods = now_playing(production_class, through)
    prods = prods.reject(&:festival_grouped?) if exclude_festival
    if prods.empty?
      future_prods = productions.select do |p|
        p.first_playing_date > Date.today && p.visible? && p.production_class == production_class &&
          (!exclude_festival || !p.festival_grouped?)
      end.sort { |p1, p2| p1.first_preview_at <=> p2.first_preview_at }
      prods = [future_prods.first] unless future_prods.empty?
    end
    prods
  end

  def <=>(other)
    ordinal_sort <=> other.ordinal_sort
  end
end
