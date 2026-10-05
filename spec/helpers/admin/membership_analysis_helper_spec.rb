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
end
