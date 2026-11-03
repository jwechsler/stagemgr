class Venue < ApplicationRecord
  validates :name, :ordinal_sort, presence: true
  has_many :productions, inverse_of: :venue
  has_many :seat_maps, inverse_of: :venue

  # SQL mirror of Production#first_playing_date before its 10-years-out default.
  FIRST_PLAYING_SQL = 'COALESCE(productions.first_preview_at, productions.press_opening_at, productions.opening_at)'.freeze

  # The SQL narrows the rows loaded (a venue holds hundreds of past
  # productions); the Ruby predicates still decide, so behaviour is exactly
  # that of filtering every production.
  def now_playing(production_class, through = nil)
    current_candidates(production_class).select do |p|
      p.now_playing?(through) && p.visible? && p.production_class == production_class
    end
  end

  def now_playing_or_next_up(production_class, through = nil)
    prods = now_playing(production_class, through)
    if prods.empty?
      future_prods = future_candidates(production_class).select do |p|
        p.first_playing_date > Date.current && p.visible? && p.production_class == production_class
      end.sort { |p1, p2| p1.first_preview_at <=> p2.first_preview_at }
      prods = [future_prods.first] unless future_prods.empty?
    end
    prods
  end

  def <=>(other)
    ordinal_sort <=> other.ordinal_sort
  end

  private

  def visible_productions(production_class)
    productions.where(status: Production.visible_statuses, production_class: production_class)
  end

  # Not yet closed; Production#now_playing? decides the rest.
  def current_candidates(production_class)
    visible_productions(production_class).where('productions.closing_at IS NULL OR productions.closing_at >= ?',
                                                Date.current)
  end

  # First playing date in the future, or no dates at all (first_playing_date
  # then falls back to ten years out, which is always in the future).
  def future_candidates(production_class)
    visible_productions(production_class).where("#{FIRST_PLAYING_SQL} > ? OR #{FIRST_PLAYING_SQL} IS NULL",
                                                Date.current)
  end
end
