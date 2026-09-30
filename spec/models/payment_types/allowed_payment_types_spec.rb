require 'rails_helper'

# The payment types an order page offers are the ones its performance allows
# (TicketOrder#valid_payment_types_for), narrowed through the one filter the
# shared billing form applies (PaymentType.restrict_to).
RSpec.describe PaymentType, 'allowed payment types' do
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let!(:card)       { FactoryBot.create(:credit_card_payment_type) }
  let!(:cash)       { FactoryBot.create(:cash_payment_type) }
  let!(:membership) { FactoryBot.create(:membership_payment_type) }
  let(:performance) { FactoryBot.create(:performance) }

  describe 'TicketOrder#valid_payment_types_for' do
    it "hides a type the performance restricts, and nothing else" do
      PaymentRestriction.create!(performance: performance, payment_type: membership)

      offered = TicketOrder.new(performance: performance.reload).valid_payment_types_for(box_office_user)

      expect(offered).to include(card, cash)
      expect(offered.map(&:id)).not_to include(membership.id)
    end
  end

  describe '.restrict_to' do
    it 'keeps only the allowed types, compared by id' do
      comp = FactoryBot.create(:external_payment_type)
      goldstar = ExternalPaymentType.create!(display_name: 'Goldstar')

      expect(described_class.restrict_to([card, comp, goldstar, membership], [card, goldstar]))
        .to eq([card, goldstar])
    end

    it 'returns every type when no allowed list is given' do
      expect(described_class.restrict_to([card, membership], nil)).to eq([card, membership])
    end
  end
end
