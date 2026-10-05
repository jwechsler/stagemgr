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

  describe 'ended_at stamping on close' do
    it 'stamps ended_at when status transitions to Canceled without one' do
      membership = FactoryBot.create(:library_pass)

      membership.update!(status: Membership::CANCELED)

      expect(membership.reload.ended_at).to eq(Date.current)
    end

    it 'stamps ended_at when status transitions to Expired without one' do
      membership = FactoryBot.create(:library_pass)

      membership.update!(status: Membership::EXPIRED)

      expect(membership.reload.ended_at).to eq(Date.current)
    end

    it 'does not stamp ended_at on suspension' do
      membership = FactoryBot.create(:library_pass)

      membership.update!(status: Membership::SUSPENDED)

      expect(membership.reload.ended_at).to be_nil
    end

    it 'keeps a Stripe-provided ended_at authoritative' do
      membership = FactoryBot.create(:membership, ended_at: Date.new(2026, 3, 1))

      membership.update!(status: Membership::CANCELED)

      expect(membership.reload.ended_at).to eq(Date.new(2026, 3, 1))
    end

    it 'does not clear ended_at when a membership reactivates' do
      membership = FactoryBot.create(:library_pass)
      membership.update!(status: Membership::CANCELED)

      membership.update!(status: Membership::ACTIVE)

      expect(membership.reload.ended_at).to eq(Date.current)
    end
  end

  describe 'ended_at sync from the Stripe subscription' do
    let(:membership) do
      FactoryBot.create(:membership, profile_id: 'sub_test_sync', status: Membership::ACTIVE,
                                     ended_at: Date.new(2026, 7, 25))
    end

    def sync_with(status:, ended_at: nil)
      price = { 'price' => Struct.new(:unit_amount).new(2900) }
      subscription = Struct.new(:start_date, :ended_at, :items, :current_period_end, :cancel_at_period_end, :status,
                                keyword_init: true)
                           .new(start_date: Time.zone.local(2021, 10, 9).to_i, ended_at: ended_at&.to_i,
                                items: Struct.new(:data).new([price]),
                                current_period_end: Time.zone.local(2026, 10, 9).to_i,
                                cancel_at_period_end: false, status: status)
      allow(membership).to receive(:get_profile_data).and_return(subscription)
      membership.update_from_profile
    end

    it 'clears a stale ended_at when the subscription is active again' do
      sync_with(status: 'active')

      expect(membership.ended_at).to be_nil
      expect(membership.status).to eq(Membership::ACTIVE)
    end

    it 'clears a stale ended_at for a trialing subscription' do
      sync_with(status: 'trialing')

      expect(membership.ended_at).to be_nil
    end

    it "takes Stripe's ended_at when the subscription has ended" do
      sync_with(status: 'canceled', ended_at: Time.zone.local(2026, 9, 1, 12))

      expect(membership.ended_at).to eq(Date.new(2026, 9, 1))
    end

    it 'keeps an existing ended_at when a past-due subscription has no end date' do
      sync_with(status: 'past_due')

      expect(membership.ended_at).to eq(Date.new(2026, 7, 25))
      expect(membership.status).to eq(Membership::SUSPENDED)
    end
  end

  describe 'syncing a membership with no Stripe subscription' do
    it 'keeps the status of a PayPal-era membership' do
      membership = FactoryBot.create(:membership, profile_id: 'I-1TJFPJGB64Y9', status: Membership::ACTIVE)

      membership.update_from_profile

      expect(membership.status).to eq(Membership::ACTIVE)
    end

    it 'keeps the status of a canceled membership with no profile' do
      membership = FactoryBot.create(:membership, profile_id: nil, status: Membership::CANCELED,
                                                  ended_at: Date.new(2025, 1, 1))

      membership.update_from_profile

      expect(membership.status).to eq(Membership::CANCELED)
    end

    it 'starts a membership with no status yet as Pending' do
      membership = Membership.new(profile_id: nil, status: nil)

      membership.update_from_profile

      expect(membership.status).to eq(Membership::PENDING)
    end

    it 'never reads Stripe for it' do
      membership = FactoryBot.create(:membership, profile_id: 'I-1TJFPJGB64Y9', status: Membership::ACTIVE)
      allow(membership).to receive(:get_profile_data)

      membership.update_from_profile

      expect(membership).not_to have_received(:get_profile_data)
    end
  end

  describe '#verify_bookable_this_week!' do
    it 'is a no-op for production offers' do
      offer = FactoryBot.create(:membership_offer)
      membership = FactoryBot.create(:membership, membership_offer: offer)
      order = FactoryBot.create(:ticket_order, :for_a_single_ticket,
                                performance: FactoryBot.create(:general_admission,
                                                               performance_date: Date.current + 60.days))

      expect { membership.verify_bookable_this_week!(order) }.not_to raise_error
    end
  end

  describe 'MyEmma list sync' do
    let(:membership) { FactoryBot.create(:membership) }

    context 'when MyEmma is enabled' do
      before { allow(MyEmma).to receive(:disabled?).and_return(false) }

      it 'enqueues a sync job when the status changes' do
        expect(Resque).to receive(:enqueue).with(SyncMembershipMyEmmaJob, membership.id)

        membership.update!(status: Membership::CANCELED)
      end

      it 'does not enqueue on a save that leaves status unchanged' do
        membership # create before setting the expectation

        expect(Resque).not_to receive(:enqueue).with(SyncMembershipMyEmmaJob, anything)

        membership.update!(member_since: Date.yesterday)
      end
    end

    it 'does not enqueue when MyEmma is disabled (test default)' do
      membership

      expect(Resque).not_to receive(:enqueue).with(SyncMembershipMyEmmaJob, anything)

      membership.update!(status: Membership::CANCELED)
    end
  end

  describe '#patron_member_since_year' do
    let(:address) { FactoryBot.create(:address) }
    let(:offer)   { FactoryBot.create(:membership_offer) }

    it 'uses the earliest membership on the address, not this one' do
      FactoryBot.create(:membership, address: address, membership_offer: offer, member_code: 'TW-OLD01',
                                     status: Membership::CANCELED, member_since: Date.new(2014, 3, 1))
      current = FactoryBot.create(:membership, address: address, membership_offer: offer, member_code: 'TW-NEW01',
                                               member_since: Date.new(2023, 9, 1))

      expect(current.patron_member_since_year).to eq(2014)
    end

    it 'prefers the Stripe start_date over member_since when present' do
      membership = FactoryBot.create(:membership, address: address, membership_offer: offer,
                                                  member_since: Date.new(2020, 1, 1), start_date: Date.new(2018, 6, 1))

      expect(membership.patron_member_since_year).to eq(2018)
    end

    it 'ignores pending memberships that never activated' do
      FactoryBot.create(:membership, address: address, membership_offer: offer, member_code: 'TW-PEN01',
                                     status: Membership::PENDING, member_since: Date.new(2010, 1, 1))
      current = FactoryBot.create(:membership, address: address, membership_offer: offer, member_code: 'TW-ACT01',
                                               member_since: Date.new(2021, 5, 5))

      expect(current.patron_member_since_year).to eq(2021)
    end

    it 'falls back to its own dates when the address has no qualifying memberships' do
      membership = FactoryBot.build(:membership, address: address, membership_offer: offer,
                                                 status: Membership::PENDING, member_since: Date.new(2019, 2, 2))

      expect(membership.patron_member_since_year).to eq(2019)
    end
  end
end
