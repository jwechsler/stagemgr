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

  describe '#has_flex_pass?' do
    it 'is true for a patron whose order carries an active flex pass' do
      order = FactoryBot.create(:flex_pass_order)

      expect(order.address.has_flex_pass?).to be(true)
    end

    it 'is false once that flex pass is inactive' do
      order = FactoryBot.create(:flex_pass_order)
      order.flex_pass_line_item.flex_pass.update!(active: false)

      expect(order.address.has_flex_pass?).to be(false)
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

    it "takes the newer record's middle name only when present" do
      original = FactoryBot.build(:address, first_name: 'Alicia', middle_name: 'M')

      original.update_from(FactoryBot.build(:address, first_name: 'Alice', middle_name: ''))
      expect([original.first_name, original.middle_name]).to eq(%w[Alice M])

      original.update_from(FactoryBot.build(:address, first_name: 'Alice', middle_name: 'Q.'))
      expect(original.middle_name).to eq('Q.')
    end
  end

  describe '#revenue_collected' do
    let(:since_when) { 30.days.ago }

    def settled_order(address, status: Order::PROCESSED, **attrs)
      order = FactoryBot.create(:ticket_order, address: address, **attrs)
      order.update_columns(status: status)
      order
    end

    def pay(order, amount, processed_on: 1.day.ago)
      payment = FactoryBot.create(:cash_payment, order: order, amount: amount)
      payment.update_columns(processed_on: processed_on)
      payment
    end

    it "sums only the payments on this address's own settled orders in the window" do
      alice = FactoryBot.create(:address)
      bob = FactoryBot.create(:address)
      pay(settled_order(alice), 10.00)
      pay(settled_order(alice, status: Order::FULFILLED), 15.50)
      pay(settled_order(bob), 7.25)

      expect(alice.revenue_collected(since_when)).to eq(BigDecimal('25.50'))
      expect(bob.revenue_collected(since_when)).to eq(BigDecimal('7.25'))
    end

    it 'excludes unsettled orders, payments before the window and orders it only receives as a gift' do
      patron = FactoryBot.create(:address)
      giver = FactoryBot.create(:address)
      pay(settled_order(patron), 10.00)
      pay(settled_order(patron, status: Order::CANCELED), 100.00)
      pay(settled_order(patron), 200.00, processed_on: since_when - 1.day)
      gift = settled_order(giver)
      gift.update_columns(recipient_address_id: patron.id)
      pay(gift, 400.00)

      expect(patron.revenue_collected(since_when)).to eq(BigDecimal('10.00'))
      expect(giver.revenue_collected(since_when)).to eq(BigDecimal('400.00'))
    end

    it 'returns a number that customer_tag can truncate' do
      patron = FactoryBot.create(:address)
      pay(settled_order(patron), 12.75)

      expect(patron.customer_tag).to start_with('0021')
    end
  end
end
