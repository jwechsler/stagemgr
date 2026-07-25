require 'rails_helper'

RSpec.describe TextSanitizable do
  # The exact value the box office pasted into the performance form, byte-order
  # marks and all, which raised
  #   Mysql2::Error: Incorrect string value: '\xEF\xBB\xBFBla...'
  let(:pasted_payload) do
    "﻿[1] Blackout Night: This performance is specifically dedicated " \
      "to serving and celebrating ﻿Black-identifying theatergoers and " \
      'the Black community at large.'
  end

  describe '.scrub' do
    it 'strips the byte-order marks that broke the performance update' do
      scrubbed = described_class.scrub(pasted_payload)

      expect(scrubbed).not_to include("﻿")
      expect(scrubbed).to eq('[1] Blackout Night: This performance is specifically dedicated ' \
                             'to serving and celebrating Black-identifying theatergoers and ' \
                             'the Black community at large.')
    end

    it 'strips zero-width spaces and joiners' do
      expect(described_class.scrub("zero​width‌join‍ed")).to eq('zerowidthjoined')
    end

    it 'strips soft hyphens' do
      expect(described_class.scrub("soft­hyphen")).to eq('softhyphen')
    end

    it 'strips bidi controls and invisible operators' do
      expect(described_class.scrub("a‮b⁠c⁦d")).to eq('abcd')
    end

    it 'preserves the typography that pasted copy legitimately uses' do
      typography = "Curly “quotes”, em—dash, en–dash, ellipsis… " \
                   "bullet • café naïve £2.50 ™"

      expect(described_class.scrub(typography)).to eq(typography)
    end

    it 'leaves plain ASCII untouched' do
      expect(described_class.scrub('Opening night, 7:30PM')).to eq('Opening night, 7:30PM')
    end

    # These used to be stripped, because latin1 could not store them. The tables
    # are utf8mb4 now, so they are ordinary content.
    it 'preserves emoji and non-Latin scripts' do
      expect(described_class.scrub("Emoji \u{1F389} and CJK 你好")).to eq("Emoji \u{1F389} and CJK 你好")
    end

    it 'drops invalid byte sequences instead of raising' do
      invalid = "caf\xE9 unflagged".dup.force_encoding(Encoding::UTF_8)

      expect(invalid).not_to be_valid_encoding
      expect(described_class.scrub(invalid)).to eq('caf unflagged')
    end

    it 'always returns valid UTF-8' do
      [pasted_payload, "“quoted” café", "emoji \u{1F389}", ''].each do |value|
        scrubbed = described_class.scrub(value)

        expect(scrubbed.encoding).to eq(Encoding::UTF_8)
        expect(scrubbed).to be_valid_encoding
      end
    end

    it 'passes non-string values straight through' do
      expect(described_class.scrub(nil)).to be_nil
      expect(described_class.scrub(42)).to eq(42)
      expect(described_class.scrub(Date.new(2026, 10, 29))).to eq(Date.new(2026, 10, 29))
    end
  end

  describe '#scrub_string_attributes' do
    let(:production) { FactoryBot.create(:production, capacity: 10) }

    it 'scrubs every string attribute on the record' do
      performance = FactoryBot.build(:performance, production: production,
                                                   special_feature_display_markdown: pasted_payload,
                                                   special_feature_email_markdown: "email​copy")

      performance.scrub_string_attributes

      expect(performance.special_feature_display_markdown).not_to include("﻿")
      expect(performance.special_feature_email_markdown).to eq('emailcopy')
    end

    it 'leaves a clean record undirtied' do
      performance = FactoryBot.create(:performance, production: production,
                                                    special_feature_display_markdown: 'Clean copy')
      performance.reload

      performance.scrub_string_attributes

      expect(performance).not_to be_changed
    end
  end
end
