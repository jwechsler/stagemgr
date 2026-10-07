require 'rails_helper'

RSpec.describe FlexPassOffer, type: :model do
  describe 'active and on-sale-to-public' do
    it 'activates an offer that is put on sale to the public' do
      offer = FactoryBot.create(:flex_pass_offer, active: false, on_sale_to_public: true)

      expect(offer.reload).to be_active
    end

    it 'stays inactive and comes off public sale when an on-sale offer is deactivated' do
      offer = FactoryBot.create(:flex_pass_offer, active: true, on_sale_to_public: true)

      offer.update!(active: false)

      expect(offer.reload).not_to be_active
      expect(offer).not_to be_on_sale_to_public
    end

    it 'keeps an inactive offer that is not on public sale inactive' do
      offer = FactoryBot.create(:flex_pass_offer, active: true, on_sale_to_public: false)

      offer.update!(active: false)

      expect(offer.reload).not_to be_active
    end
  end

  describe '.with_outstanding and .without_outstanding' do
    let(:outstanding_offer) { FactoryBot.create(:flex_pass_offer, name: 'Outstanding', number_of_tickets: 2) }
    let(:spent_offer) { FactoryBot.create(:flex_pass_offer, name: 'Spent', number_of_tickets: 2) }
    let(:unsold_offer) { FactoryBot.create(:flex_pass_offer, name: 'Unsold') }

    before { allow(Resque).to receive(:enqueue_in) }

    def sell_pass(offer)
      FactoryBot.create(:flex_pass_order, flex_pass_offer: offer).flex_pass_line_item.flex_pass
    end

    it 'counts an offer outstanding only while one of its passes is FlexPass.outstanding' do
      sell_pass(outstanding_offer)
      sell_pass(spent_offer).update_columns(expiration_date: Date.current - 1)
      sell_pass(spent_offer).update_columns(active: false)
      exhausted = sell_pass(spent_offer)
      FactoryBot.create(:flex_pass_payment, order: exhausted.order, flex_pass: exhausted, number_of_tickets: 2)
      unsold_offer

      expect(FlexPassOffer.with_outstanding).to contain_exactly(outstanding_offer)
      expect(FlexPassOffer.without_outstanding).to contain_exactly(spent_offer, unsold_offer)
    end
  end

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
        expect(offer.errors[:price]).to include('is not a number')
      end

      it 'requires price to be non-negative' do
        offer = FactoryBot.build(:flex_pass_offer, price: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:price]).to include('must be greater than or equal to 0')
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
        expect(offer.errors[:facility_fee]).to include('is not a number')
      end

      it 'requires facility_fee to be non-negative when present' do
        offer = FactoryBot.build(:flex_pass_offer, facility_fee: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:facility_fee]).to include('must be greater than or equal to 0')
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
        expect(offer.errors[:spiff]).to include('is not a number')
      end

      it 'requires spiff to be non-negative when present' do
        offer = FactoryBot.build(:flex_pass_offer, spiff: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:spiff]).to include('must be greater than or equal to 0')
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
        expect(offer.errors[:flat_payout]).to include('is not a number')
      end

      it 'requires flat_payout to be non-negative when present' do
        offer = FactoryBot.build(:flex_pass_offer, flat_payout: -1)
        expect(offer).not_to be_valid
        expect(offer.errors[:flat_payout]).to include('must be greater than or equal to 0')
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
                                price: 999_999.99,
                                facility_fee: 999_999.99,
                                spiff: 999_999.99,
                                flat_payout: 999_999.99)

      offer.reload
      expect(offer.price).to eq(999_999.99)
      expect(offer.facility_fee).to eq(999_999.99)
      expect(offer.spiff).to eq(999_999.99)
      expect(offer.flat_payout).to eq(999_999.99)
    end
  end

  describe 'currency formatting' do
    let(:offer) do
      FactoryBot.build(:flex_pass_offer,
                       price: 10.50,
                       facility_fee: 2.75,
                       spiff: 1.50,
                       flat_payout: 5.00)
    end

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

  describe 'autofulfill configuration' do
    # Performance#clean_values rounds times down to 15-minute blocks — stagger
    # by full blocks so same-production performances stay unique.
    def performance_of(production)
      @performance_offset = (@performance_offset || 0) + 1
      FactoryBot.create(:general_admission, production: production,
                                            performance_time: Time.now + (@performance_offset * 15).minutes)
    end

    def offer_with(codes, **attrs)
      FactoryBot.build(:flex_pass_offer,
                       autofulfill_performance_codes: codes,
                       maximum_uses_per_performance: 2,
                       number_of_tickets: 10,
                       **attrs)
    end

    let(:production) { FactoryBot.create(:production) }
    let(:performance) { performance_of(production) }

    it 'parses the code list, stripping blanks and normalizing case' do
      offer = offer_with(" abc01 ,DEF02,, ghi03 ")
      expect(offer.autofulfill_performance_code_list).to eq(%w[ABC01 DEF02 GHI03])
      expect(offer).to be_autofulfill
    end

    it 'is valid with a blank code list' do
      expect(offer_with(nil)).to be_valid
      expect(offer_with('')).to be_valid
      expect(offer_with(' , ')).to be_valid
    end

    it 'is valid with existing general admission performances' do
      other = performance_of(production)
      expect(offer_with("#{performance.performance_code},#{other.performance_code}")).to be_valid
    end

    it 'rejects unknown performance codes' do
      offer = offer_with('NOSUCH99')
      expect(offer).not_to be_valid
      expect(offer.errors[:autofulfill_performance_codes]).to include(
        'includes unknown performance code NOSUCH99'
      )
    end

    it 'rejects duplicate performance codes' do
      offer = offer_with("#{performance.performance_code},#{performance.performance_code}")
      expect(offer).not_to be_valid
      expect(offer.errors[:autofulfill_performance_codes].join).to include('duplicate performance codes')
    end

    it 'rejects reserved seating performances' do
      reserved = FactoryBot.create(:reserved_seating)
      offer = offer_with(reserved.performance_code)
      expect(offer).not_to be_valid
      expect(offer.errors[:autofulfill_performance_codes].join).to include('reserved seating')
    end

    it 'requires a non-zero maximum_uses_per_performance' do
      [nil, 0].each do |maximum|
        offer = offer_with(performance.performance_code, maximum_uses_per_performance: maximum)
        expect(offer).not_to be_valid
        expect(offer.errors[:maximum_uses_per_performance].join).to include('must be set')
      end
    end

    it 'rejects a code list needing more tickets than the pass holds' do
      other = performance_of(production)
      offer = offer_with("#{performance.performance_code},#{other.performance_code}",
                         maximum_uses_per_performance: 3, number_of_tickets: 5)
      expect(offer).not_to be_valid
      expect(offer.errors[:autofulfill_performance_codes].join).to include('requires 6 tickets')
    end

    it 'rejects a configuration that would always exceed the per-production cap' do
      other = performance_of(production)
      offer = offer_with("#{performance.performance_code},#{other.performance_code}",
                         maximum_uses_per_production: 3)
      expect(offer).not_to be_valid
      expect(offer.errors[:autofulfill_performance_codes].join).to include('maximum uses per production')
    end

    it 'allows a configuration within the per-production cap' do
      other = performance_of(production)
      offer = offer_with("#{performance.performance_code},#{other.performance_code}",
                         maximum_uses_per_production: 4)
      expect(offer).to be_valid
    end
  end

  describe '#recoverable_at_expiry' do
    it 'is the price less the flat payout and facility fee' do
      offer = FactoryBot.build(:flex_pass_offer, price: 25, flat_payout: 10, facility_fee: 2.5, spiff: 4)

      expect(offer.recoverable_at_expiry).to eq(BigDecimal('12.5'))
    end

    it 'floors at zero' do
      offer = FactoryBot.build(:flex_pass_offer, price: 0, flat_payout: 10, facility_fee: 2)

      expect(offer.recoverable_at_expiry).to eq(0)
    end

    it 'treats nil fees as zero' do
      offer = FactoryBot.build(:flex_pass_offer, price: 25, flat_payout: nil, facility_fee: nil)

      expect(offer.recoverable_at_expiry).to eq(BigDecimal('25'))
    end
  end

  describe 'autofulfill helpers' do
    let(:production) { FactoryBot.create(:production) }
    let!(:first) { FactoryBot.create(:general_admission, production: production, performance_time: Time.current) }
    let!(:second) do
      FactoryBot.create(:general_admission, production: production, performance_time: 30.minutes.from_now)
    end

    it 'requires unique codes times uses per performance' do
      offer = FactoryBot.build(:flex_pass_offer, maximum_uses_per_performance: 2,
                                                 autofulfill_performance_codes: 'ABC01,abc01,DEF02')

      expect(offer.autofulfill_tickets_required).to eq(4)
    end

    it 'is zero without autofulfill codes or a per-performance cap' do
      expect(FactoryBot.build(:flex_pass_offer, maximum_uses_per_performance: 2).autofulfill_tickets_required).to eq(0)
      expect(FactoryBot.build(:flex_pass_offer, autofulfill_performance_codes: 'ABC01').autofulfill_tickets_required)
        .to eq(0)
    end

    it 'pairs each code with its performance in list order, nil when unknown' do
      offer = FactoryBot.build(:flex_pass_offer,
                               autofulfill_performance_codes: "#{second.performance_code},NOSUCH99,#{first.performance_code}")

      expect(offer.autofulfill_performances_by_code).to eq(
        [[second.performance_code, second], ['NOSUCH99', nil], [first.performance_code, first]]
      )
    end
  end
end
