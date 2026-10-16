# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TicketOrder, '#build_tktprint_payload print flags' do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_single_ticket) }
  let(:address) { order.address }
  let(:payload) { order.reload.send(:build_tktprint_payload, 'BATCH-1', 1) }

  before do
    address.update!(vip: false, donor_tier_for_current_fiscal_year: nil, donor_tier_for_last_fiscal_year: nil)
    order.update!(notes: nil)
  end

  it 'sends no flags for a non-VIP patron with no tier and an order with no notes' do
    expect(payload[:flags]).to eq([])
  end

  it 'sends a star for a VIP patron' do
    address.update!(vip: true)

    expect(payload[:flags]).to eq(['star'])
  end

  describe 'the donor flag' do
    it 'is sent for a current-fiscal-year tier the install does not exclude' do
      address.update!(donor_tier_for_current_fiscal_year: '$100-$249.99')

      expect(payload[:flags]).to eq(['flag'])
    end

    it 'is not sent for a current-fiscal-year tier the test config excludes' do
      address.update!(donor_tier_for_current_fiscal_year: 'Up to $99.99')

      expect(payload[:flags]).to eq([])
    end

    it 'is not sent for a nil current-fiscal-year tier' do
      expect(payload[:flags]).to eq([])
    end

    it 'is not sent for a blank current-fiscal-year tier' do
      address.update!(donor_tier_for_current_fiscal_year: '   ')

      expect(payload[:flags]).to eq([])
    end

    it 'is not sent for a patron with only a last-fiscal-year tier' do
      address.update!(donor_tier_for_last_fiscal_year: '$100-$249.99')

      expect(payload[:flags]).to eq([])
    end

    it 'is sent for every current-fiscal-year tier when no tiers are excluded' do
      allow(Lgl).to receive(:settings).and_return(Lgl::Settings.from({ 'littlegreenlight' => {} }, env: {}))
      address.update!(donor_tier_for_current_fiscal_year: 'Up to $99.99')

      expect(payload[:flags]).to eq(['flag'])
    end
  end

  it 'sends a checkmark when the order has notes' do
    order.update!(notes: 'Needs an aisle seat')

    expect(payload[:flags]).to eq(['checkmark'])
  end

  it 'sends no checkmark for whitespace-only notes' do
    order.update!(notes: "  \n\t ")

    expect(payload[:flags]).to eq([])
  end

  it 'sends star, flag and checkmark in rule order when all apply' do
    address.update!(vip: true, donor_tier_for_current_fiscal_year: '$100-$249.99')
    order.update!(notes: 'Birthday')

    expect(payload[:flags]).to eq(%w[star flag checkmark])
  end

  describe 'reprinting an order already in tktprint' do
    let(:http) { instance_double(Net::HTTP, 'use_ssl=': nil) }
    let(:sent_requests) { [] }

    before do
      allow(Rails.configuration.x).to receive(:tktprint).and_return('service' => 'http://user:secret@tktprint.test:3000')
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:request) do |request|
        sent_requests << request
        instance_double(Net::HTTPOK, code: '200', body: '{}')
      end
      order.update!(print_order_id: 42)
    end

    def sent_body
      expect(sent_requests.size).to eq(1)
      expect(sent_requests.first).to be_a(Net::HTTP::Put)
      expect(sent_requests.first.path).to eq('/orders/42/reprint.json')
      JSON.parse(sent_requests.first.body)
    end

    it 'includes the flags in the PUT body' do
      address.update!(vip: true)
      order.update!(notes: 'Birthday')

      order.reload.send_to_printer_api('BATCH-1', 1)

      expect(sent_body['flags']).to eq(%w[star checkmark])
    end

    it 'sends an empty flags list when nothing applies' do
      order.reload.send_to_printer_api('BATCH-1', 1)

      body = sent_body
      expect(body).to have_key('flags')
      expect(body['flags']).to eq([])
    end
  end
end
