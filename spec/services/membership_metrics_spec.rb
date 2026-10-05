require 'rails_helper'

RSpec.describe MembershipMetrics do
  describe '.overlap_days' do
    def overlap(coverage_start, coverage_end, span_start = 0, span_end = 100)
      described_class.overlap_days(coverage_start, coverage_end, span_start, span_end)
    end

    it 'counts every day of a coverage inside the span' do
      expect(overlap(10, 40)).to eq(30)
    end

    it 'counts only the days inside the span' do
      expect(overlap(90, 120)).to eq(10)
      expect(overlap(-20, 10)).to eq(10)
    end

    it 'counts nothing when the coverage misses the span' do
      expect(overlap(100, 130)).to eq(0)
      expect(overlap(-30, 0)).to eq(0)
    end
  end
end
