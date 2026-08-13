require 'rails_helper'

RSpec.describe PrinterTextSanitizer, type: :service do
  # Invisible characters are built from codepoints so this file stays free of
  # characters an editor can't display.
  let(:nbsp) { [0x00A0].pack('U') }
  let(:zero_width_space) { [0x200B].pack('U') }
  let(:combining_diaeresis) { [0x0308].pack('U') }
  let(:non_latin1_re) { /[^\x00-ÿ]/ }

  describe '.sanitize' do
    it 'returns nil for nil input' do
      expect(described_class.sanitize(nil)).to be_nil
    end

    it 'leaves plain ASCII untouched' do
      expect(described_class.sanitize('Plain ASCII 123 - $9.50')).to eq('Plain ASCII 123 - $9.50')
    end

    it 'keeps Latin-1 characters unchanged' do
      expect(described_class.sanitize('Café')).to eq('Café')
      expect(described_class.sanitize('señor über ½')).to eq('señor über ½')
    end

    it 'maps typographic characters to functional ASCII equivalents and drops emoji' do
      expect(described_class.sanitize('Zoë’s “Big” Show — Act 1… 🎭'))
        .to eq('Zoë\'s "Big" Show - Act 1...')
    end

    it 'transliterates non-Latin-1 letters to their nearest equivalent' do
      expect(described_class.sanitize('Łódź')).to eq('Lódz')
    end

    it 'expands ligatures via NFKC' do
      expect(described_class.sanitize('ﬁne')).to eq('fine')
    end

    it 'recomposes decomposed accents into Latin-1 codepoints' do
      decomposed = "Zoe#{combining_diaeresis}"
      expect(described_class.sanitize(decomposed)).to eq('Zoë')
    end

    it 'converts non-breaking spaces to plain spaces' do
      expect(described_class.sanitize("front#{nbsp}row")).to eq('front row')
    end

    it 'removes zero-width characters' do
      expect(described_class.sanitize("Show#{zero_width_space}time")).to eq('Showtime')
    end

    it 'reduces an emoji-only string to an empty string' do
      expect(described_class.sanitize('🎭🎉')).to eq('')
    end

    it 'strips control characters' do
      expect(described_class.sanitize("bad#{0x00.chr}#{0x9C.chr(Encoding::UTF_8)}input")).to eq('badinput')
    end

    it 'never emits characters outside the Latin-1 repertoire' do
      samples = ['Café', 'Łódź', '日本語 Show 🎭', "a#{nbsp}—#{zero_width_space}b", 'ǅungla']
      samples.each do |sample|
        expect(described_class.sanitize(sample)).not_to match(non_latin1_re)
      end
    end
  end

  describe '.sanitize_payload' do
    it 'sanitizes strings nested inside attribute arrays and leaves other values untouched' do
      payload = {
        title: 'Zoë’s Show — 🎭',
        amount: BigDecimal('42.5'),
        remote_id: 17,
        performance_date: Date.new(2026, 8, 13),
        credit_1: nil,
        line_items_attributes: [
          { description: '“Premium” seat…', amount: 25 }
        ],
        tickets_attributes: [
          { ticket_class: 'GA', seat: "A–1#{nbsp}" }
        ]
      }

      result = described_class.sanitize_payload(payload)

      expect(result[:title]).to eq('Zoë\'s Show -')
      expect(result[:amount]).to eq(BigDecimal('42.5'))
      expect(result[:remote_id]).to eq(17)
      expect(result[:performance_date]).to eq(Date.new(2026, 8, 13))
      expect(result[:credit_1]).to be_nil
      expect(result[:line_items_attributes].first[:description]).to eq('"Premium" seat...')
      expect(result[:line_items_attributes].first[:amount]).to eq(25)
      expect(result[:tickets_attributes].first[:seat]).to eq('A-1')
      expect(result.to_json).not_to match(non_latin1_re)
    end
  end
end
