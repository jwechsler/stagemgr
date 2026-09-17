# frozen_string_literal: true

require 'rails_helper'

# Renders against synthetic artwork with the Helvetica fallback fonts, then
# reads the PNG back and checks geometry rather than pixels-for-pixels, so
# the assertions hold whichever Helvetica stand-in fontconfig supplies.
RSpec.describe MembershipCards::Renderer, :membership_cards do
  let(:renderer) { described_class.new }
  let(:background_path) { image_file(synthetic_background) }
  let(:photo_box) { card_spec.photo_box.rounded }

  def inputs(**overrides)
    MembershipCards::Renderer::Inputs.new(
      { background_path: background_path, front_path: nil, photo_path: nil,
        name_font: helvetica_bold, label_font: helvetica,
        name: 'Jo Ann', member_number: 'TW-ABC123', year: '2019' }.merge(overrides)
    )
  end

  def render(**overrides)
    Vips::Image.new_from_buffer(renderer.render(inputs(**overrides)), '')
  end

  it 'produces an opaque PNG at the card size tagged 300 dpi' do
    out = render

    expect([out.width, out.height, out.bands]).to eq([card_spec.width, card_spec.height, 3])
    expect(out.xres).to be_within(0.01).of(card_spec.dpi / 25.4)
    expect(out.yres).to be_within(0.01).of(card_spec.dpi / 25.4)
  end

  it 'rejects a background that is not the card size' do
    stale = image_file(synthetic_background(width: 1000, height: 600))

    expect { renderer.render(inputs(background_path: stale)) }
      .to raise_error(MembershipCards::RenderError, /1000x600/)
  end

  describe 'the photo' do
    let(:out) { render(photo_path: image_file(synthetic_photo)) }
    let(:panel) { out.extract_area(photo_box.x, photo_box.y, photo_box.w, photo_box.h) }

    it 'fills the photo panel' do
      expect(panel.avg).to be > 0
    end

    it 'is desaturated (every pixel has R == G == B)' do
      expect((panel[0] - panel[1]).abs.max).to eq(0)
      expect((panel[1] - panel[2]).abs.max).to eq(0)
    end

    it 'does not spill outside the panel' do
      outside = out.draw_rect([0, 0, 0], photo_box.x, photo_box.y, photo_box.w, photo_box.h, fill: true)
      # Only the text fields may light up elsewhere; black them out too.
      right_of_text = outside.extract_area(photo_box.x - 20, 0, 20, card_spec.height)
      expect(right_of_text.max).to eq(0)
    end
  end

  it 'composites the front overlay above the photo' do
    out = render(photo_path: image_file(synthetic_photo), front_path: image_file(synthetic_front))

    expect(out.getpoint(720, 120)).to eq([255, 0, 0])
  end

  describe 'the text fields' do
    let(:out) { render }
    let(:name_box) { card_spec.name_rules.box.rounded }
    let(:number) { card_spec.field(:member_id) }
    let(:since)  { card_spec.field(:since) }
    # Generous regions: the field's x to the next field, baseline minus an em
    # to baseline plus a third of an em for descenders.
    let(:number_region) { [number.x.round, (number.baseline - number.font_size).round, (since.x - number.x).round, (number.font_size * 1.4).round] }
    let(:since_region)  { [since.x.round, (since.baseline - since.font_size).round, 200, (since.font_size * 1.4).round] }
    let(:name_region)   { [name_box.x, name_box.y, name_box.w, name_box.h + 20] }

    it 'draws ink in each of the three fields' do
      expect(out.extract_area(*number_region).max).to be > 0
      expect(out.extract_area(*since_region).max).to be > 0
      expect(out.extract_area(*name_region).max).to be > 0
    end

    it 'draws nothing outside those fields' do
      masked = [number_region, since_region, name_region].reduce(out) do |img, (x, y, w, h)|
        img.draw_rect([0, 0, 0], x, y, w, h, fill: true)
      end
      expect(masked.max).to eq(0)
    end

    it 'sits the member number on its baseline' do
      flat = render(member_number: 'HHH')
      expect(bottom_ink_row(flat, *number_region)).to be_within(1).of(number.baseline.round)
    end

    it 'sits a single-line name on the first baseline at the maximum size' do
      flat = render(name: 'HHHH')
      rules = card_spec.name_rules
      expected = rules.box.y + (rules.first_baseline_ratio * rules.max_font_size)
      expect(bottom_ink_row(flat, *name_region)).to be_within(1).of(expected.round)
    end

    it 'wraps a long double-barrelled name onto two lines' do
      two = render(name: 'Alexandra Ellsworth-Vance')
      rows = two.extract_area(*name_region)[0].project[1] # 1 x h column of row sums
      lit = (0...rows.height).select { |y| rows.getpoint(0, y).first > 0 }
      runs = lit.slice_when { |a, b| b > a + 1 }.to_a

      expect(runs.size).to eq(2)
    end

    it 'colours each field as the spec says' do
      flat = render(member_number: 'HHH', year: 'HHH')
      # The fully covered pixels of a glyph take the field's colour exactly.
      number_peak = (0..2).map { |band| flat.extract_area(*number_region)[band].max }
      since_peak  = (0..2).map { |band| flat.extract_area(*since_region)[band].max }

      expect(number_peak).to eq(number.color)
      expect(since_peak).to eq(since.color)
    end

    it 'sets the since year apart from the member number' do
      expect(since.color).not_to eq(number.color)
    end
  end

  it 'renders with neither photo nor overlay' do
    out = render
    expect(out.extract_area(photo_box.x, photo_box.y, photo_box.w, photo_box.h).max).to eq(0)
  end
end
