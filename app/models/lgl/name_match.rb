# frozen_string_literal: true

module Lgl
  # First-name comparison used to narrow an email + last name match between
  # Stagemgr customers and LGL constituents, in both directions.
  #
  # Only the first word counts, downcased with trailing punctuation dropped:
  # LGL keeps one first name per constituent, so a couple's record says
  # "Glen" while Stagemgr may hold "Glen" and "Beth" separately, and middle
  # initials ("Alden L.", "B.") vary between the two systems.
  module NameMatch
    module_function

    # "Alden L." -> "alden", "B." -> "b", blank -> nil.
    def first_name_key(name)
      token = name.to_s.strip.split(/\s+/).first.to_s
      token.sub(/[[:punct:]]+\z/, '').downcase.presence
    end

    # True when both first names are present and share a key.
    def same_first_name?(first, second)
      key = first_name_key(first)
      key.present? && key == first_name_key(second)
    end

    # The +items+ whose first name (read by the block) matches +first_name+,
    # or nil when +first_name+ is blank: then no narrowing is possible and the
    # caller keeps its email + last name result. An item with a blank first
    # name never matches, so a name-less stray record cannot keep a couple in
    # review.
    def narrow(first_name, items)
      key = first_name_key(first_name)
      return nil if key.nil?

      items.select { |item| first_name_key(yield(item)) == key }
    end
  end
end
