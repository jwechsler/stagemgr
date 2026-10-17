# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::GiftReplicator do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:client) { instance_double(Lgl::Client) }
  let(:event_ensurer) { instance_double(Lgl::EventEnsurer, ensure_for: 33) }
  let(:appeal_ensurer) { instance_double(Lgl::AppealEnsurer, ensure_for_season: 22) }
  let(:go_live) { Time.zone.local(2026, 10, 1, 9, 0, 0) }

  # Go-live first, so gifts_since precedes the order.
  let(:order) do
    travel_to(go_live) { LglSetting.store_campaign(1092, '2026 Individual Giving') }
    travel_to(go_live + 1.day) do
      FactoryBot.create(:donation_order_for_one_thousand_dollars, :for_production, theater: house).tap do |o|
        FactoryBot.create(:credit_card_payment, order: o, amount: 1000.0, processed_on: Time.current,
                                                confirmation_code: 'ch_test123', card_type: 'Visa',
                                                card_last_four: '4242')
        o.update!(status: Order::PROCESSED)
        o.address.set_lgl_id!(900_050)
      end
    end
  end

  subject(:replicator) { described_class.new(order.reload, client) }

  before do
    allow(client).to receive_messages(search_gifts_by_external_ids: [], create_gift: { 'id' => 7001 })
    allow(Lgl::EventEnsurer).to receive(:new).and_return(event_ensurer)
    allow(Lgl::AppealEnsurer).to receive(:new).and_return(appeal_ensurer)
  end

  describe '#replicate gates' do
    def expect_skipped(reason)
      outcome = replicator.replicate
      expect(outcome.to_a).to eq([:skipped, nil, reason])
      expect(client).not_to have_received(:create_gift)
    end

    it 'skips a donation credited to another theater' do
      order.update_column(:theater_id, FactoryBot.create(:theater).id)
      expect_skipped('not credited to the default theater')
    end

    it 'skips an order that is not processed' do
      order.update_column(:status, Order::HOLD)
      expect_skipped('not processed')
    end

    it 'replicates a fulfilled order' do
      order.update_column(:status, Order::FULFILLED)
      expect(replicator.replicate.action).to eq(:created)
    end

    it 'skips a donation created before go-live' do
      order.update_column(:created_at, go_live - 1.minute)
      expect_skipped('before go-live')
    end

    it 'skips everything while no campaign has been chosen (no go-live stamp)' do
      order
      LglSetting.delete_all
      expect_skipped('before go-live')
    end

    it 'warns and skips when the campaign was cleared after go-live' do
      order
      LglSetting.where(key: LglSetting::CAMPAIGN_ID).delete_all
      allow(Rails.logger).to receive(:warn)

      expect_skipped('no campaign')
      expect(Rails.logger).to have_received(:warn).with(a_string_including('no LGL campaign'))
    end

    it 'skips a placeholder address' do
      order.address.update_column(:placeholder, true)
      expect_skipped('no address')
    end

    it 'skips an unlinked address awaiting LGL review' do
      order.address.clear_lgl_id!
      order.address.lgl_review!('2 LGL constituents share this email')
      expect_skipped('awaiting LGL review')
    end

    it 'raises NotLinked for an unlinked address so the job retries' do
      order.address.clear_lgl_id!

      expect { replicator.replicate }
        .to raise_error(described_class::NotLinked, "address ##{order.address_id} has no LGL constituent yet")
      expect(client).not_to have_received(:create_gift)
    end
  end

  describe '#replicate idempotency' do
    it 'stops at a gift id already on the order' do
      order.update_column(:lgl_gift_id, 6001)

      expect(replicator.replicate.to_a).to eq([:already_replicated, 6001, 'gift id on order'])
      expect(client).not_to have_received(:search_gifts_by_external_ids)
      expect(client).not_to have_received(:create_gift)
    end

    it 'adopts a gift LGL already has under the external id' do
      allow(client).to receive(:search_gifts_by_external_ids)
        .with(["stagemgr-#{order.id}"]).and_return([{ 'id' => 6002 }])

      expect(replicator.replicate.to_a).to eq([:adopted, 6002, 'external id matched'])
      expect(order.reload.lgl_gift_id).to eq(6002)
      expect(client).not_to have_received(:create_gift)
    end
  end

  describe '#replicate create path' do
    it 'creates the gift with campaign, appeal, event and external id, and stores its id' do
      outcome = replicator.replicate

      expect(outcome.to_a).to eq([:created, 7001, 'gift written'])
      expect(client).to have_received(:create_gift)
        .with('900050', hash_including(external_id: "stagemgr-#{order.id}", campaign_id: 1092, appeal_id: 22,
                                       event_id: 33, received_amount: 1000.0),
              for_address_id: order.address_id)
      expect(order.reload.lgl_gift_id).to eq(7001)
      expect(JobMetadata.recorded?(described_class::LAST_GIFT)).to be(true)
    end

    it "ensures the production's event and season appeal on the chosen campaign" do
      replicator.replicate

      args = { campaign_id: 1092, for_address_id: order.address_id }
      expect(Lgl::EventEnsurer).to have_received(:new).with(client, **args)
      expect(event_ensurer).to have_received(:ensure_for).with(order.production)
      expect(appeal_ensurer).to have_received(:ensure_for_season).with(order.production.season)
    end

    it 'uses the received year as the season and sends no event when there is no production' do
      order.update_columns(production_id: nil, campaign: 'Online')

      replicator.replicate

      expect(Lgl::EventEnsurer).not_to have_received(:new)
      expect(appeal_ensurer).to have_received(:ensure_for_season).with(2026)
      expect(client).to have_received(:create_gift)
        .with('900050', satisfy { |body| !body.key?(:event_id) }, for_address_id: order.address_id)
    end

    it 'stores nothing when the create is skipped read-only' do
      allow(client).to receive(:create_gift).and_return(nil)

      expect(replicator.replicate.to_a).to eq([:skipped, nil, 'read-only'])
      expect(order.reload.lgl_gift_id).to be_nil
      expect(JobMetadata.recorded?(described_class::LAST_GIFT)).to be(false)
    end

    it 'notes a refund that landed during the run' do
      allow(client).to receive(:create_gift) do
        order.update_column(:status, Order::REFUNDED)
        { 'id' => 7001 }
      end
      allow(client).to receive_messages(find_gift: { 'id' => 7001, 'note' => 'Stagemgr donation' },
                                        update_gift: { 'id' => 7001 })

      outcome = replicator.replicate

      expect(outcome.to_a).to eq([:created, 7001, 'gift written; refund noted'])
      expect(client).to have_received(:update_gift)
        .with(7001, hash_including(note: a_string_including('Refunded in Stagemgr on')),
              for_address_id: order.address_id)
    end
  end

  describe '#note_refund' do
    before { order.update_columns(lgl_gift_id: 7001, status: Order::REFUNDED) }

    it 'skips when the order has no gift' do
      order.update_column(:lgl_gift_id, nil)
      expect(replicator.note_refund.to_a).to eq([:skipped, nil, 'no gift to note'])
    end

    it 'warns when LGL no longer has the gift' do
      allow(client).to receive(:find_gift).with(7001).and_return(nil)
      allow(Rails.logger).to receive(:warn)

      expect(replicator.note_refund.to_a).to eq([:gift_missing, 7001, 'LGL answered 404'])
      expect(Rails.logger).to have_received(:warn).with(a_string_including('gift 7001 not found'))
    end

    it 'leaves a gift already noted unchanged' do
      allow(client).to receive(:find_gift).and_return({ 'id' => 7001, 'note' => 'Refunded in Stagemgr on 2026-10-02' })
      expect(client).not_to receive(:update_gift)

      expect(replicator.note_refund.to_a).to eq([:unchanged, 7001, 'already noted'])
    end

    it 'appends the refund note to the existing note' do
      allow(client).to receive_messages(find_gift: { 'id' => 7001, 'note' => 'Thanks!' }, update_gift: { 'id' => 7001 })

      expect(replicator.note_refund.to_a).to eq([:noted, 7001, 'refund note added'])
      expect(client).to have_received(:update_gift)
        .with(7001, hash_including(note: a_string_starting_with("Thanks!\nRefunded in Stagemgr on")),
              for_address_id: order.address_id)
    end

    it 'reports a read-only skip' do
      allow(client).to receive_messages(find_gift: { 'id' => 7001, 'note' => nil }, update_gift: nil)
      expect(replicator.note_refund.to_a).to eq([:skipped, nil, 'read-only'])
    end
  end
end
