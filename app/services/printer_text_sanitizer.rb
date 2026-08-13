# Restricts text to the Latin-1 repertoire for the Boca FGL ticket printer.
# The tktprint daemon writes payload strings straight to the printer socket,
# and the printer renders from a Latin-1-class code page, so anything outside
# that repertoire prints as garbage. Latin-1 characters (é, ñ, ü, ½ ...) pass
# through unchanged; typographic marks map to functional ASCII equivalents;
# other letters are transliterated; unmappable characters (emoji) are removed.
class PrinterTextSanitizer
  TYPOGRAPHIC_MAP = {
    "‘" => "'", "’" => "'", "‚" => "'", "‛" => "'", # curly single quotes
    "“" => '"', "”" => '"', "„" => '"', "‟" => '"', # curly double quotes
    "′" => "'", "″" => '"', # prime marks
    "‐" => '-', "‑" => '-', "‒" => '-', "–" => '-', # hyphens, en dash
    "—" => '-', "―" => '-', "−" => '-', # em dash, horizontal bar, minus
    "…" => '...', # ellipsis
    "\u00A0" => ' ', "\u2007" => ' ', "\u2009" => ' ', # NBSP and thin spaces
    "\u200A" => ' ', "\u202F" => ' ', "\u3000" => ' ',
    "•" => '*',                                                    # bullet
    "\u200B" => '', "\u200C" => '', "\u200D" => '', "\uFEFF" => '' # zero-width characters
  }.freeze
  TYPOGRAPHIC_RE = Regexp.union(TYPOGRAPHIC_MAP.keys).freeze
  NON_LATIN1_RE = /[^\x00-\u00FF]/
  CONTROL_RE = /[\x00-\x1F\x7F-\u009F]/

  class << self
    # Sanitize one string. Identity on ASCII/Latin-1 input; nil-safe.
    def sanitize(text)
      return text if text.nil?

      s = text.to_s.scrub('').unicode_normalize(:nfc) # NFC recomposes e + U+0308 into ë; NOT NFKC (would mangle ½/²)
      s = s.gsub(TYPOGRAPHIC_RE, TYPOGRAPHIC_MAP)
      s = s.gsub(NON_LATIN1_RE) { |ch| transliterate_char(ch) }
      s.gsub(CONTROL_RE, '').gsub(/ {2,}/, ' ').strip
    end

    # Deep-sanitize every String value in a payload hash, including strings
    # nested inside the *_attributes arrays. Non-string values pass through.
    def sanitize_payload(payload)
      payload.deep_transform_values { |v| v.is_a?(String) ? sanitize(v) : v }
    end

    private

    def transliterate_char(char)
      d = char.unicode_normalize(:nfkc) # ligatures/fullwidth -> ASCII
      d = I18n.transliterate(d, replacement: '') if d.match?(NON_LATIN1_RE)
      d.gsub(NON_LATIN1_RE, '') # anything still unmappable (emoji) vanishes
    end
  end
end
