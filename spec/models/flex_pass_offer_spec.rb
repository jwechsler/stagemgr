require 'rails_helper'

RSpec.describe FlexPassOffer, type: :model do
  describe 'validations' do
    describe 'price' do
      it 'accepts decimal values' do
        offer = FactoryBot.build(:flex_pass_offer, price: 10.50)
        expect(offer).to be_valid
        expect(offer.price).to eq(10.50)
      end

      it 'requires price to be present' do
        offer = FactoryBot.build(:flex_pass_offer, price: nil)
        expect(offer).not_to be_valid
        expect(offer.errors[:price]).to include("can't be blank")
      end

      it 'requires price to be numeric' do
        offer = FactoryBot.build(:flex_pass_offer, price: 'not a number')
        expect(offer).not_to be_valid
        expect(offer.errors[:price]).to include("is not a number")
      end

      it 'requires price to be non-negative' do
        offer = FactoryBot.build(:flex_pass_offer, price: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:price]).to include("must be greater than or equal to 0")
      end
    end

    describe 'facility_fee' do
      it 'accepts decimal values' do
        offer = FactoryBot.build(:flex_pass_offer, facility_fee: 2.75)
        expect(offer).to be_valid
        expect(offer.facility_fee).to eq(2.75)
      end

      it 'allows nil values' do
        offer = FactoryBot.build(:flex_pass_offer, facility_fee: nil)
        expect(offer).to be_valid
      end

      it 'requires facility_fee to be numeric when present' do
        offer = FactoryBot.build(:flex_pass_offer, facility_fee: 'not a number')
        expect(offer).not_to be_valid
        expect(offer.errors[:facility_fee]).to include("is not a number")
      end

      it 'requires facility_fee to be non-negative when present' do
        offer = FactoryBot.build(:flex_pass_offer, facility_fee: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:facility_fee]).to include("must be greater than or equal to 0")
      end
    end

    describe 'spiff' do
      it 'accepts decimal values' do
        offer = FactoryBot.build(:flex_pass_offer, spiff: 1.50)
        expect(offer).to be_valid
        expect(offer.spiff).to eq(1.50)
      end

      it 'allows nil values' do
        offer = FactoryBot.build(:flex_pass_offer, spiff: nil)
        expect(offer).to be_valid
      end

      it 'requires spiff to be numeric when present' do
        offer = FactoryBot.build(:flex_pass_offer, spiff: 'not a number')
        expect(offer).not_to be_valid
        expect(offer.errors[:spiff]).to include("is not a number")
      end

      it 'requires spiff to be non-negative when present' do
        offer = FactoryBot.build(:flex_pass_offer, spiff: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:spiff]).to include("must be greater than or equal to 0")
      end
    end

    describe 'flat_payout' do
      it 'accepts decimal values' do
        offer = FactoryBot.build(:flex_pass_offer, flat_payout: 5.25)
        expect(offer).to be_valid
        expect(offer.flat_payout).to eq(5.25)
      end

      it 'allows nil values' do
        offer = FactoryBot.build(:flex_pass_offer, flat_payout: nil)
        expect(offer).to be_valid
      end

      it 'requires flat_payout to be numeric when present' do
        offer = FactoryBot.build(:flex_pass_offer, flat_payout: 'not a number')
        expect(offer).not_to be_valid
        expect(offer.errors[:flat_payout]).to include("is not a number")
      end

      it 'requires flat_payout to be non-negative when present' do
        offer = FactoryBot.build(:flex_pass_offer, flat_payout: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:flat_payout]).to include("must be greater than or equal to 0")
      end
    end
  end

  describe 'currency precision' do
    it 'stores values with exactly 2 decimal places' do
      offer = FactoryBot.create(:flex_pass_offer,
                                price: 10.999,
                                facility_fee: 2.333,
                                spiff: 1.777,
                                flat_payout: 5.444)

      offer.reload
      expect(offer.price).to eq(11.00)
      expect(offer.facility_fee).to eq(2.33)
      expect(offer.spiff).to eq(1.78)
      expect(offer.flat_payout).to eq(5.44)
    end

    it 'handles very small decimal values' do
      offer = FactoryBot.create(:flex_pass_offer,
                                price: 0.01,
                                facility_fee: 0.01,
                                spiff: 0.01,
                                flat_payout: 0.01)

      offer.reload
      expect(offer.price).to eq(0.01)
      expect(offer.facility_fee).to eq(0.01)
      expect(offer.spiff).to eq(0.01)
      expect(offer.flat_payout).to eq(0.01)
    end

    it 'handles large monetary values' do
      offer = FactoryBot.create(:flex_pass_offer,
                                price: 999999.99,
                                facility_fee: 999999.99,
                                spiff: 999999.99,
                                flat_payout: 999999.99)

      offer.reload
      expect(offer.price).to eq(999999.99)
      expect(offer.facility_fee).to eq(999999.99)
      expect(offer.spiff).to eq(999999.99)
      expect(offer.flat_payout).to eq(999999.99)
    end
  end

  describe 'currency formatting' do
    let(:offer) {
      FactoryBot.build(:flex_pass_offer,
                       price: 10.50,
                       facility_fee: 2.75,
                       spiff: 1.50,
                       flat_payout: 5.00)
    }

    it 'formats price as currency' do
      expect(offer.formatted_price).to eq('$10.50')
    end

    it 'formats facility_fee as currency' do
      expect(offer.formatted_facility_fee).to eq('$2.75')
    end

    it 'formats spiff as currency' do
      expect(offer.formatted_spiff).to eq('$1.50')
    end

    it 'formats flat_payout as currency' do
      expect(offer.formatted_flat_payout).to eq('$5.00')
    end

    it 'handles nil values in formatting' do
      offer.facility_fee = nil
      offer.spiff = nil
      offer.flat_payout = nil

      expect(offer.formatted_facility_fee).to eq('$0.00')
      expect(offer.formatted_spiff).to eq('$0.00')
      expect(offer.formatted_flat_payout).to eq('$0.00')
    end
  end
end
