require 'rails_helper'

RSpec.describe ZoneHelper do
  let(:seat_map) { FactoryBot.create(:seat_map, seat_count: 0) }

  def add_seat(zone)
    FactoryBot.create(:seat, seat_map: seat_map, zone: zone)
  end

  describe '#zone_stroke_color (per-map assignment)' do
    it "assigns palette entries by the zone position among the map's sorted zones" do
      %w[B QR A].each { |z| add_seat(z) }
      # sorted progression: A, B, QR
      expect(helper.zone_stroke_color('A', seat_map)).to eq(ZoneHelper::ZONE_STROKE_PALETTE[0])
      expect(helper.zone_stroke_color('B', seat_map)).to eq(ZoneHelper::ZONE_STROKE_PALETTE[1])
      expect(helper.zone_stroke_color('QR', seat_map)).to eq(ZoneHelper::ZONE_STROKE_PALETTE[2])
    end

    it 'never repeats a color until the map uses more zones than the palette' do
      zones = %w[A B AA ZZ BB QR ST B1] # the 8-zone example
      zones.each { |z| add_seat(z) }
      colors = zones.map { |z| helper.zone_stroke_color(z, seat_map) }
      expect(colors.uniq.length).to eq(zones.length) # 8 zones, 10 colors: all distinct
    end

    it 'wraps only past the palette size' do
      zones = ('A'..'L').to_a # 12 zones on a 10-color palette
      zones.each { |z| add_seat(z) }
      expect(helper.zone_stroke_color('K', seat_map)).to eq(helper.zone_stroke_color('A', seat_map))
      expect(helper.zone_stroke_color('L', seat_map)).to eq(helper.zone_stroke_color('B', seat_map))
    end
  end

  describe '#zone_stroke_style' do
    it 'renders a full-opacity thickened stroke in the zone color' do
      add_seat('A')
      style = helper.zone_stroke_style('A', seat_map)
      expect(style).to include("stroke:#{ZoneHelper::ZONE_STROKE_PALETTE[0]}")
      expect(style).to include('stroke-width:4')
      expect(style).to include('stroke-opacity:1')
    end
  end
end
