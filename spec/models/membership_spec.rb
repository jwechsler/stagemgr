require 'rails_helper'

RSpec.describe Membership do
  describe 'order-less (library pass) memberships' do
    it 'can be canceled without an associated order' do
      membership = FactoryBot.create(:library_pass)

      expect { membership.update!(status: Membership::CANCELED) }.not_to raise_error
    end

    it 'cancels cleanly even when it has an outstanding reservation' do
      travel_to(Date.new(2025, 6, 11)) do
        membership = FactoryBot.create(:library_pass)
        order = FactoryBot.create(:ticket_order, :for_a_single_ticket,
                                  address: FactoryBot.create(:address),
                                  performance: FactoryBot.create(:general_admission,
                                                                 performance_date: Date.new(2025, 6, 15)))
        order.payments << FactoryBot.build(:membership_payment, number_of_tickets: 1,
                                                                membership: membership, amount: 0)
        order.status = Order::PROCESSED
        order.save!(validate: false)

        expect { membership.update!(status: Membership::CANCELED) }.not_to raise_error
      end
    end

    it 'can be suspended without an associated order (notify guard is nil-safe)' do
      membership = FactoryBot.create(:library_pass)

      expect { membership.update!(status: Membership::SUSPENDED) }.not_to raise_error
    end
  end

  describe '#verify_bookable_this_week!' do
    it 'is a no-op for production offers' do
      offer = FactoryBot.create(:membership_offer)
      membership = FactoryBot.create(:membership, membership_offer: offer)
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket,
                                performance: FactoryBot.create(:general_admission,
                                                               performance_date: Date.today + 60.days))

      expect { membership.verify_bookable_this_week!(order) }.not_to raise_error
    end
  end
end
