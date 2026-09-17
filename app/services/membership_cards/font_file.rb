# frozen_string_literal: true

module MembershipCards
  # Reads the family and style names out of an OpenType/TrueType file so the
  # renderer can hand Pango a description that actually matches the uploaded
  # font. This matters because libvips' `fontfile` option silently falls back
  # to the default sans when the `font` string names a family the file does
  # not contain -- a filename like "Sketchnote Text Bold.otf" is not a
  # reliable source of that name.
  #
  # Only the `name` table is parsed (nameIDs 1/2 and the typographic 16/17).
  # No third-party gem: ttfunk is not in the bundle and this is ~40 lines.
  class FontFile
    class Invalid < StandardError; end

    SFNT_TAGS = ["OTTO", "\x00\x01\x00\x00".b, 'true'].freeze
    WINDOWS_PLATFORM = 3
    MAC_PLATFORM = 1
    ENGLISH_US = 0x409
    TYPOGRAPHIC_FAMILY, TYPOGRAPHIC_STYLE, FAMILY, STYLE = 16, 17, 1, 2

    attr_reader :family, :style

    def initialize(path)
      @path = path
      @names = {}
      parse(File.binread(path))
      @family = @names[TYPOGRAPHIC_FAMILY] || @names[FAMILY] or raise Invalid, "#{path}: no family name"
      @style  = @names[TYPOGRAPHIC_STYLE] || @names[STYLE] || 'Regular'
    end

    # "Sketchnote Text Bold", or just "Sketchnote Square" for a Regular face.
    def pango_family
      style.casecmp?('Regular') ? family : "#{family} #{style}"
    end

    def to_font
      Font.new(@path, pango_family)
    end

    private

    def parse(data)
      raise Invalid, "#{@path}: not an OpenType or TrueType font" unless SFNT_TAGS.include?(data[0, 4])

      num_tables = data[4, 2].unpack1('n')
      records = Array.new(num_tables) { |i| data[12 + (16 * i), 16].unpack('a4NNN') }
      _tag, _checksum, offset, length = records.find { |tag, *| tag == 'name' }
      raise Invalid, "#{@path}: no name table" if offset.nil?

      parse_name_table(data[offset, length])
    end

    # Each record is (platform, encoding, language, nameID, length, offset).
    # Windows/English wins; a Mac Roman record fills in when that is absent.
    def parse_name_table(table)
      _format, count, string_offset = table.unpack('nnn')
      priority = {}
      count.times do |i|
        platform, _encoding, language, name_id, length, offset = table[6 + (12 * i), 12].unpack('n6')
        next unless [TYPOGRAPHIC_FAMILY, TYPOGRAPHIC_STYLE, FAMILY, STYLE].include?(name_id)

        rank = record_rank(platform, language)
        next if rank.nil? || (priority[name_id] && priority[name_id] <= rank)

        value = decode(table[string_offset + offset, length], platform)
        next if value.nil? || value.empty? # rubocop:disable Rails/Blank -- loaded without Rails by bin/render-membership-card

        @names[name_id] = value
        priority[name_id] = rank
      end
    end

    def record_rank(platform, language)
      return 0 if platform == WINDOWS_PLATFORM && language == ENGLISH_US
      return 1 if platform == WINDOWS_PLATFORM
      return 2 if platform == MAC_PLATFORM

      nil
    end

    def decode(bytes, platform)
      return nil if bytes.nil?

      if platform == WINDOWS_PLATFORM
        bytes.force_encoding('UTF-16BE').encode('UTF-8')
      else
        bytes.force_encoding('MacRoman').encode('UTF-8')
      end.strip
    rescue EncodingError
      nil
    end
  end
end
