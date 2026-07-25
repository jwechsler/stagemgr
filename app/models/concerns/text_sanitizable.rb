# Box office staff compose copy in Word, Google Docs or e-mail and paste it into
# the admin forms. That text arrives carrying invisible formatting characters --
# byte-order marks, zero-width spaces, soft hyphens, bidi controls -- which are
# never intended and which nobody can see to remove by hand.
#
# The tables are utf8mb4, so these characters no longer break the save (they used
# to, on the latin1 columns: "Mysql2::Error: Incorrect string value"). They now
# store happily and invisibly instead, which is worse -- a byte-order mark
# lodged mid-sentence in web copy and confirmation e-mails that nobody notices.
# So strip them on the way in.
#
# Legitimate content is left alone: curly quotes, em dashes, ellipses, accented
# letters, emoji and non-Latin scripts all survive untouched.
#
#   include TextSanitizable
#   before_validation :scrub_string_attributes
module TextSanitizable
  extend ActiveSupport::Concern

  # U+00AD soft hyphen, U+200B-U+200F zero-width and bidi marks,
  # U+202A-U+202E bidi embedding, U+2060-U+2064 invisible operators,
  # U+2066-U+2069 bidi isolates, U+FEFF byte-order mark.
  INVISIBLE_CHARACTERS = /[­​-‏‪-‮⁠-⁤⁦-⁩﻿]/

  def self.scrub(value)
    return value unless value.is_a?(String)

    # String#scrub first: gsub raises ArgumentError on invalid byte sequences,
    # which is how a paste from a mis-declared source arrives, and MySQL would
    # reject those bytes as invalid utf8mb4 anyway.
    value.scrub('').gsub(INVISIBLE_CHARACTERS, '')
  end

  # Rewrites every string attribute in place. Only changed values are assigned,
  # so a record that pastes cleanly is never marked dirty.
  def scrub_string_attributes
    attributes.each do |name, value|
      next unless value.is_a?(String)

      scrubbed = TextSanitizable.scrub(value)
      self[name] = scrubbed unless scrubbed == value
    end
  end
end
