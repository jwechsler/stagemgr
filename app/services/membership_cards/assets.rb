# frozen_string_literal: true

module MembershipCards
  # Materialises an offer's card artwork (and the patron's photo) from
  # ActiveStorage into files libvips can open, and hands back the fonts as
  # Font descriptors -- the fontconfig fallbacks when the offer has none.
  #
  # Images go to Tempfiles that are unlinked when the block returns, the same
  # pattern as Address#cap_photo_resolution. Fonts are different: libvips
  # registers a `fontfile` with fontconfig for the life of the process, keyed
  # by path, so a fresh Tempfile per render would pile up registrations that
  # point at deleted files. Fonts therefore land at a stable path under tmp/,
  # named by blob checksum, written once and never removed while the app runs.
  class Assets
    FONT_DIR = Rails.root.join('tmp/membership_card_fonts')
    FALLBACK_NAME_FONT  = 'Helvetica Bold'
    FALLBACK_LABEL_FONT = 'Helvetica'

    Bundle = Struct.new(:background_path, :front_path, :photo_path, :name_font, :label_font, keyword_init: true)

    def self.with(offer, photo = nil, &)
      new(offer, photo).with(&)
    end

    def initialize(offer, photo)
      @offer = offer
      @photo = photo
      @tempfiles = []
    end

    def with
      yield Bundle.new(
        background_path: tempfile_for(@offer.card_background),
        front_path: tempfile_for(@offer.card_front_overlay),
        photo_path: tempfile_for(@photo),
        name_font: font_for(@offer.card_name_font, FALLBACK_NAME_FONT),
        label_font: font_for(@offer.card_label_font, FALLBACK_LABEL_FONT)
      )
    ensure
      @tempfiles.each do |file|
        file.close
        FileUtils.rm_f(file.path)
      end
    end

    private

    def tempfile_for(attachment)
      return nil unless attachment&.attached?

      blob = attachment.blob
      file = Tempfile.new(['membership_card', ".#{blob.filename.extension}"])
      file.binmode
      blob.download { |chunk| file.write(chunk) }
      file.flush
      @tempfiles << file
      file.path
    end

    def font_for(attachment, fallback_family)
      return Font.fallback(fallback_family) unless attachment&.attached?

      FontFile.new(stable_font_path(attachment.blob)).to_font
    rescue FontFile::Invalid => e
      Rails.logger.warn("[MembershipCards] offer #{@offer.id}: #{e.message}; using #{fallback_family}")
      Font.fallback(fallback_family)
    end

    # Written atomically so a concurrent request never opens a half-written
    # file: fontconfig would cache the failure for the rest of the process.
    def stable_font_path(blob)
      FileUtils.mkdir_p(FONT_DIR)
      path = FONT_DIR.join("#{blob.checksum.tr('/+=', '_')}.#{blob.filename.extension.presence || 'otf'}")
      return path.to_s if path.exist?

      partial = "#{path}.#{Process.pid}.tmp"
      File.open(partial, 'wb') { |f| blob.download { |chunk| f.write(chunk) } }
      File.rename(partial, path)
      path.to_s
    end
  end
end
