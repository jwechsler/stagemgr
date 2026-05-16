require 'rails_helper'

RSpec.describe AudienceCohortReport do
  # Stub Production.find — segment-name building only needs production_code
  # and (optionally) name/season. The full create flow is exercised by manual
  # smoke testing; here we focus on the pure-logic segment-name builder.
  def stub_production(code, name: 'Some Show', season: 2025)
    instance_double(Production, id: 42, production_code: code, name: name, season: season).tap do |p|
      allow(Production).to receive(:find).with(42).and_return(p)
    end
  end

  describe "#segment_name" do
    it "joins production_code, metric label, and window phrase" do
      stub_production('SHOW-X')
      r = described_class.new(42, [1], :first_time_vs_comparison, "3 months", false, [], 99)
      expect(r.segment_name).to eq("SHOW-X - First Time (group) - Last 3mo")
    end

    it "omits the window phrase for non-windowed segments" do
      stub_production('SHOW-X')
      r = described_class.new(42, [1], :cohort, nil, false, [], 99)
      expect(r.segment_name).to eq("SHOW-X - Attendees")
    end

    it "renders 'Returning from <CODE>' for previous_production keys" do
      stub_production('SHOW-X')
      prev = instance_double(Production, production_code: 'OLD-Y')
      allow(Production).to receive(:find_by).with(id: 777).and_return(prev)

      r = described_class.new(42, [1], "previous_production:777", nil, false, [], 99)
      expect(r.segment_name).to eq("SHOW-X - Returning from OLD-Y")
    end

    it "is capped at 50 characters" do
      stub_production('LONGCODE')
      r = described_class.new(42, [1], :first_time_vs_comparison, "3 months", false, [], 99)
      expect(r.segment_name.length).to be <= AudienceCohortReport::SEGMENT_NAME_LIMIT
    end

    it "drops the window first when over the cap, keeping production_code + metric" do
      stub_production('AAAAAAAA') # 8 chars (max production_code length)
      # Force a metric label that fits without the window but overflows with it.
      # AAAAAAAA (8) + " - " (3) + label + " - Last 3mo" (11) > 50 → drop window.
      # AAAAAAAA (8) + " - " (3) + label ≤ 50 → keep metric.
      stub_const("AudienceCohortReport::METRIC_LABELS", {
        "first_time_vs_comparison" => "First Time Visitor (group qualifier)"  # 36 chars
      }.freeze)

      r = described_class.new(42, [1], :first_time_vs_comparison, "3 months", false, [], 99)
      expect(r.segment_name).to eq("AAAAAAAA - First Time Visitor (group qualifier)")
      expect(r.segment_name).not_to include("Last 3mo")
      expect(r.segment_name.length).to be <= 50
    end
  end
end
