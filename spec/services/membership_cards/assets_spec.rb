# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipCards::Assets, :membership_cards do
  let(:offer) { FactoryBot.create(:membership_offer) }

  before do
    offer.card_background.attach(blob_for(synthetic_background, 'background.png'))
  end

  it 'materialises the background to a file libvips can open' do
    described_class.with(offer) do |assets|
      image = Vips::Image.new_from_file(assets.background_path)
      expect([image.width, image.height]).to eq([card_spec.width, card_spec.height])
    end
  end

  it 'removes the temporary image files when the block returns' do
    paths = nil
    described_class.with(offer) { |assets| paths = [assets.background_path] }

    expect(paths).to all(satisfy { |path| !File.exist?(path) })
  end

  it 'leaves the front overlay and photo nil when absent' do
    described_class.with(offer) do |assets|
      expect(assets.front_path).to be_nil
      expect(assets.photo_path).to be_nil
    end
  end

  it 'downloads the patron photo when given one' do
    address = FactoryBot.create(:address)
    address.photo.attach(blob_for(synthetic_photo(50), 'photo.png'))

    described_class.with(offer, address.reload.photo) do |assets|
      expect(File.exist?(assets.photo_path)).to be true
    end
  end

  it 'falls back to Helvetica descriptors when the offer has no fonts' do
    described_class.with(offer) do |assets|
      expect(assets.name_font).to eq(MembershipCards::Font.fallback('Helvetica Bold'))
      expect(assets.label_font).to eq(MembershipCards::Font.fallback('Helvetica'))
    end
  end

  context 'with an uploaded font' do
    let(:font_path) { system_bold_font_path || skip('fontconfig has no bold .ttf/.otf font to upload') }

    before do
      # create_and_upload! stores the bytes now; attach(io:) would defer the
      # upload to an after_commit that never fires inside a transactional spec.
      blob = ActiveStorage::Blob.create_and_upload!(io: File.open(font_path), filename: File.basename(font_path),
                                                    content_type: 'font/ttf')
      offer.card_name_font.attach(blob)
    end

    it 'writes the font to a stable path keyed by checksum and reuses it' do
      first = nil
      second = nil
      described_class.with(offer) { |a| first = a.name_font.path }
      described_class.with(offer) { |a| second = a.name_font.path }

      expect(first).to eq(second)
      expect(first).to start_with(described_class::FONT_DIR.to_s)
      expect(File.exist?(first)).to be true
    end

    it 'names the Pango family from inside the file' do
      described_class.with(offer) do |assets|
        expect(assets.name_font.pango_family).to eq(MembershipCards::FontFile.new(font_path).pango_family)
      end
    end
  end
end
