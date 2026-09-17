# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipCards::FontFile, :membership_cards do
  # No font is committed to the repository (the house faces are licensed), so
  # parse whatever bold .ttf/.otf fontconfig has and skip when there is none.
  let(:bold_sans_path) do
    system_bold_font_path || skip('fontconfig has no bold .ttf/.otf font to parse')
  end

  it 'reads the family and style from the name table' do
    font = described_class.new(bold_sans_path)

    expect(font.family).to be_present
    expect(font.style).to match(/bold/i)
    expect(font.pango_family).to eq("#{font.family} #{font.style}")
  end

  it 'omits a Regular style from the Pango description' do
    font = described_class.new(bold_sans_path)
    allow(font).to receive(:style).and_return('Regular')

    expect(font.pango_family).to eq(font.family)
  end

  it 'wraps the file in a Font descriptor' do
    font = described_class.new(bold_sans_path).to_font

    expect(font.path).to eq(bold_sans_path)
    expect(font).not_to be_fallback
  end

  it 'rejects a file that is not an OpenType or TrueType font' do
    Tempfile.create(['not-a-font', '.otf']) do |file|
      file.write('%PDF-1.4 definitely not a font')
      file.flush

      expect { described_class.new(file.path) }
        .to raise_error(MembershipCards::FontFile::Invalid, /not an OpenType or TrueType font/)
    end
  end
end
