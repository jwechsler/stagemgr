require 'rails_helper'

RSpec.describe Address do
  describe '#is_current_member?' do
    it 'is true for a patron with an active membership bought through an order' do
      order = FactoryBot.create(:membership_order)

      expect(order.address.is_current_member?).to be(true)
      expect(order.address.active_memberships).to eq([order.membership_line_item.membership])
    end

    it 'is false for a patron who holds only a library pass' do
      pass = FactoryBot.create(:library_pass, address: FactoryBot.create(:address))

      expect(pass.address.is_current_member?).to be(false)
      expect(pass.address.active_memberships).to be_empty
    end
  end

  describe '#is_donor?' do
    it 'is true when either fiscal-year tier is present' do
      expect(FactoryBot.build(:address, donor_tier_for_last_fiscal_year: 'Gold')).to be_is_donor
      expect(FactoryBot.build(:address, donor_tier_for_current_fiscal_year: 'Silver')).to be_is_donor
    end

    it 'is false when both tiers are blank' do
      expect(FactoryBot.build(:address, donor_tier_for_last_fiscal_year: '')).not_to be_is_donor
    end
  end

  describe '#update_from' do
    it "takes the newer record's non-blank tiers column by column" do
      original = FactoryBot.build(:address, donor_tier_for_last_fiscal_year: 'Bronze',
                                            donor_tier_for_current_fiscal_year: 'Bronze')
      newer = FactoryBot.build(:address, donor_tier_for_last_fiscal_year: nil, donor_tier_for_current_fiscal_year: 'Gold')

      original.update_from(newer)

      expect(original.donor_tier_for_last_fiscal_year).to eq('Bronze')
      expect(original.donor_tier_for_current_fiscal_year).to eq('Gold')
    end
  end
end
