require 'rails_helper'

RSpec.describe Admin::MembershipAnalysisHelper, type: :helper do
  describe '#membership_length' do
    it 'shows the average length in months only, to one decimal place' do
      expect(helper.membership_length(BigDecimal('1119') / 4)).to eq('9.2 months')
    end

    it 'shows a dash when there are no memberships to average' do
      expect(helper.membership_length(nil)).to eq('—')
    end
  end

  describe '#membership_change' do
    it 'signs a rise and shows one decimal place' do
      expect(helper.membership_change(BigDecimal('12.345'))).to eq('+12.3%')
    end

    it 'shows a fall with its minus sign' do
      expect(helper.membership_change(BigDecimal(-50))).to eq('-50.0%')
    end

    it 'shows no change unsigned' do
      expect(helper.membership_change(BigDecimal(0))).to eq('0.0%')
    end

    it 'shows a dash when there was nothing to grow from' do
      expect(helper.membership_change(nil)).to eq('—')
    end
  end
end
