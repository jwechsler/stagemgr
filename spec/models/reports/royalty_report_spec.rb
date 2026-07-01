require 'rails_helper'

# Characterization spec: pins the current output of RoyaltyReport so the
# upcoming refactor cannot change the computed numbers.
#
# Ticketing fees are intentionally excluded from royalty net pending business
# review. RoyaltyReport deducts ONLY processing fees from royalty_gross; the
# facility/ticketing fee is deliberately not subtracted here.
RSpec.describe RoyaltyReport, type: :model do
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production) }

  # One settled credit-card order for a single $2.50 GEN01 ticket. The
  # credit-card payment type auto-computes a 3.9% processing fee (0.39).
  # royalty_gross for this order is the $2.50 face value; net = gross -
  # processing = 2.50 - 0.39 = 2.11 (ticketing fee intentionally excluded).
  let!(:order) do
    FactoryBot.create(:ticket_order,
                      :for_a_single_ticket,
                      :paid_with_credit_card,
                      performance: performance)
  end

  # The ticket-class code the single-ticket order actually sold (sequence
  # dependent across the suite, so derive it rather than hard-coding it).
  let(:sold_class_code) { order.ticket_line_items.first.ticket_class.class_code }
  let(:unsold_class_codes) do
    production.ticket_classes.map(&:class_code) - [sold_class_code]
  end

  subject(:result) { described_class.new([production.id]).create }

  let(:headers) { result[0] }
  let(:rows) { result[1] }
  let(:face_value_row) { rows.find { |r| r[:performance_code] == 'Face Value' } }
  let(:detail_row) { rows.find { |r| r[:display_class] == :report_detail_row } }
  let(:summary_row) { rows.find { |r| r[:display_class] == :report_summary_row } }

  describe 'header row' do
    it 'lists the fixed leading and trailing columns in order' do
      expect(headers.first(3)).to eq(%i[performance_code performance_date performance_time])
      expect(headers.last(5)).to eq(%i[paid gross processing net royalty])
    end

    it 'includes only ticket-class columns with non-zero sales' do
      expect(headers).to include(sold_class_code)
      unsold_class_codes.each { |code| expect(headers).not_to include(code) }
    end
  end

  describe 'face value sub-header row' do
    it 'shows each active ticket class royalty price' do
      expect(face_value_row[sold_class_code]).to eq(Money.new(250))
    end
  end

  describe 'detail row' do
    it 'reports royalty figures deducting only processing fees' do
      expect(detail_row[:performance_code]).to eq(performance.performance_code)
      expect(detail_row[:paid]).to eq(1)
      expect(detail_row[sold_class_code]).to eq(1)
      expect(detail_row[:gross]).to eq(Money.new(250))
      expect(detail_row[:processing]).to eq(Money.new(39))
      # Ticketing fees are intentionally excluded from royalty net pending
      # business review: net = gross - processing only.
      expect(detail_row[:net]).to eq(Money.new(211))
      expect(detail_row[:royalty]).to eq(Money.new(0))
    end
  end

  describe 'summary row' do
    it 'totals the royalty figures' do
      expect(summary_row[:performance_code]).to eq(production.production_code)
      expect(summary_row[:paid]).to eq(1)
      expect(summary_row[:gross]).to eq(Money.new(250))
      expect(summary_row[:processing]).to eq(Money.new(39))
      expect(summary_row[:net]).to eq(Money.new(211))
      expect(summary_row[:royalty]).to eq(Money.new(0))
    end
  end
end
