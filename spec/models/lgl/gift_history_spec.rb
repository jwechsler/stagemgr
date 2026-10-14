# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::GiftHistory do
  def gift(date, type: 'Gift', amount: 50)
    { 'gift_type_name' => type, 'amount' => amount, 'date' => date }
  end

  def classify(gifts, today:, start: 1)
    described_class.classify(gifts, today: Date.iso8601(today), fiscal_year_start_month: start)
  end

  describe 'with a calendar fiscal year' do
    let(:today) { '2026-10-14' }

    it 'is nil for someone who never gave' do
      expect(classify([], today: today)).to be_nil
    end

    it 'is nil for someone who gave this fiscal year, whatever they gave before' do
      expect(classify([gift('2026-02-01'), gift('2025-06-01'), gift('2019-06-01')], today: today)).to be_nil
    end

    it 'is LYBUNT for someone who gave last fiscal year only' do
      expect(classify([gift('2025-12-31')], today: today)).to eq('LYBUNT')
    end

    it 'is LYBUNT when last year and earlier years both had gifts' do
      expect(classify([gift('2025-03-01'), gift('2020-03-01')], today: today)).to eq('LYBUNT')
    end

    it 'is SYBUNT for someone whose last gift was two fiscal years ago' do
      expect(classify([gift('2024-12-31'), gift('2018-01-01')], today: today)).to eq('SYBUNT')
    end

    it 'counts every money-received type' do
      described_class::COUNTED_GIFT_TYPES.each do |type|
        expect(classify([gift('2025-05-20', type: type)], today: today)).to eq('LYBUNT'), type
      end
    end

    it 'ignores pledges and other non-money types' do
      ['Pledge', 'In Kind', 'Soft Credit', 'Peer Credit', 'Other Income'].each do |type|
        expect(classify([gift('2025-05-20', type: type)], today: today)).to be_nil, type
      end
    end

    it 'does not let a pledge this year cancel a lapsed gift' do
      expect(classify([gift('2026-05-20', type: 'Pledge'), gift('2025-05-20')], today: today)).to eq('LYBUNT')
    end

    it 'ignores zero and negative amounts' do
      expect(classify([gift('2026-05-20', amount: 0), gift('2026-06-01', amount: '-25.00'), gift('2025-05-20')],
                      today: today)).to eq('LYBUNT')
      expect(classify([gift('2025-05-20', amount: '0.00')], today: today)).to be_nil
    end

    it 'counts a gift whose amount is a decimal string' do
      expect(classify([gift('2025-05-20', amount: '10.50')], today: today)).to eq('LYBUNT')
    end

    it 'ignores gifts with a blank or invalid date' do
      gifts = [gift(nil), gift(''), gift('not-a-date'), gift('2026-13-01'), gift('2024-05-20')]

      expect(classify(gifts, today: today)).to eq('SYBUNT')
    end

    it 'ignores gifts dated in a later fiscal year' do
      expect(classify([gift('2027-02-01'), gift('2025-05-20')], today: today)).to eq('LYBUNT')
    end

    it 'puts a gift on January 1 in the new fiscal year' do
      expect(classify([gift('2026-01-01')], today: '2026-01-01')).to be_nil
      expect(classify([gift('2025-12-31')], today: '2026-01-01')).to eq('LYBUNT')
    end

    it 'still counts the current fiscal year on December 31' do
      expect(classify([gift('2026-01-01')], today: '2026-12-31')).to be_nil
      expect(classify([gift('2025-01-01')], today: '2026-12-31')).to eq('LYBUNT')
      expect(classify([gift('2024-12-31')], today: '2026-12-31')).to eq('SYBUNT')
    end
  end

  describe 'with a July fiscal year' do
    it 'is nil for a gift since July 1 of this fiscal year' do
      expect(classify([gift('2026-07-01')], today: '2026-10-14', start: 7)).to be_nil
    end

    it 'is LYBUNT for a gift in the previous July-June year' do
      expect(classify([gift('2026-06-30')], today: '2026-10-14', start: 7)).to eq('LYBUNT')
      expect(classify([gift('2025-07-01')], today: '2026-10-14', start: 7)).to eq('LYBUNT')
    end

    it 'is SYBUNT for a gift before last fiscal year' do
      expect(classify([gift('2025-06-30')], today: '2026-10-14', start: 7)).to eq('SYBUNT')
    end

    it 'places January in the fiscal year that began the previous July' do
      expect(classify([gift('2025-08-01')], today: '2026-01-01', start: 7)).to be_nil
      expect(classify([gift('2025-06-30')], today: '2026-01-01', start: 7)).to eq('LYBUNT')
    end

    it 'puts a gift on July 1 in the new fiscal year' do
      expect(classify([gift('2026-07-01')], today: '2026-07-01', start: 7)).to be_nil
      expect(classify([gift('2026-06-30')], today: '2026-07-01', start: 7)).to eq('LYBUNT')
    end

    it 'treats December 31 as mid-year' do
      expect(classify([gift('2026-06-30')], today: '2026-12-31', start: 7)).to eq('LYBUNT')
    end
  end

  it 'defaults to the configured fiscal year start and today' do
    travel_to(Time.zone.local(2026, 10, 14, 12)) do
      expect(described_class.classify([gift('2025-05-20')])).to eq('LYBUNT')
    end
  end
end
