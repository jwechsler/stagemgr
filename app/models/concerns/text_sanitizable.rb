# Box office staff compose copy in Word, Google Docs or e-mail and paste it into
# the admin forms. That text arrives carrying characters our latin1 tables cannot
# store, and the save fails with "Mysql2::Error: Incorrect string value" -- a 500
# on an invisible character nobody can see or fix in the form.
#
# scrub makes such a value storable in two passes:
#
#   1. invisible formatting codepoints (byte-order marks, zero-width spaces,
#      soft hyphens, bidi controls) are removed outright -- they are never
#      intended, and latin1 has no mapping for them
#   2. anything else latin1 cannot hold is dropped, so emoji and CJK disappear
#      rather than raising
#
# Curly quotes, em dashes, ellipses and accented letters all survive untouched.
#
#   include TextSanitizable
#   before_validation :scrub_string_attributes
module TextSanitizable
  extend ActiveSupport::Concern

  # U+00AD soft hyphen, U+200B-U+200F zero-width and bidi marks,
  # U+202A-U+202E bidi embedding, U+2060-U+2064 invisible operators,
  # U+2066-U+2069 bidi isolates, U+FEFF byte-order mark.
  INVISIBLE_CHARACTERS = /[­​-‏‪-‮⁠-⁤⁦-⁩﻿]/

  # MySQL's latin1 is Windows-1252, not ISO-8859-1: it maps the curly quotes,
  # em dash and ellipsis in 0x80-0x9F that ISO-8859-1 leaves undefined. Encoding
  # to ISO-8859-1 would silently delete that typography.
  STORABLE_ENCODING = Encoding::WINDOWS_1252

  def self.scrub(value)
    return value unless value.is_a?(String)

    # String#scrub comes first because gsub raises ArgumentError on invalid byte
    # sequences, which is how a paste from a mis-declared source arrives.
    #
    # The round trip must then end in encode, not force_encoding: force_encoding
    # relabels the Windows-1252 bytes as UTF-8 and leaves an invalid string.
    value.scrub('')
         .gsub(INVISIBLE_CHARACTERS, '')
         .encode(STORABLE_ENCODING, undef: :replace, replace: '')
         .encode(Encoding::UTF_8)
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
