require 'rails_helper'

# Characterization spec: pins the current output (header row, detail row, and
# summary/total rows) of SalesByPerformanceReport so the upcoming refactor to
# canonical revenue vocabulary cannot change the computed numbers.
RSpec.describe SalesByPerformanceReport, type: :model do
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production) }

  # One settled credit-card order for a single $2.50 GEN01 ticket. The
  # credit-card payment type auto-computes a 3.9% processing fee (0.39) and no
  # facility/ticketing fee, so net = collected - processing = 2.50 - 0.39 = 2.11.
  let!(:order) do
    FactoryBot.create(:ticket_order,
                      :for_a_single_ticket,
                      :paid_with_credit_card,
                      performance: performance)
  end

  # The ticket-class code that the single-ticket order actually sold (the
  # factory picks the first available class; its code is sequence-dependent
  # across the suite, so derive it rather than hard-coding it).
  let(:sold_class_code) { order.ticket_line_items.first.ticket_class.class_code }
  let(:unsold_class_codes) do
    production.ticket_classes.map(&:class_code) - [sold_class_code]
  end

  subject(:result) { described_class.new([production.id]).create }

  let(:headers) { result[0] }
  let(:rows) { result[1] }
  let(:detail_row) { rows.find { |r| r[:display_class] == :report_detail_row } }
  let(:summary_row) { rows.find { |r| r[:display_class] == :report_summary_row } }

  describe 'header row' do
    it 'lists the fixed leading and trailing columns in order' do
      expect(headers.first(3)).to eq(%i[performance_code performance_date performance_time])
      expect(headers.last(8)).to eq(%i[paid holds max_ticket gross collected facility processing net])
    end

    it 'includes only ticket-class columns with non-zero sales' do
      expect(headers).to include(sold_class_code)
      unsold_class_codes.each { |code| expect(headers).not_to include(code) }
    end
  end

  describe 'detail row' do
    it 'reports the per-performance revenue figures' do
      expect(detail_row[:performance_code]).to eq(performance.performance_code)
      expect(detail_row[:paid]).to eq(1)
      expect(detail_row[:holds]).to eq(0)
      expect(detail_row[sold_class_code]).to eq(1)
      expect(detail_row[:gross]).to eq(Money.new(250))
      expect(detail_row[:collected]).to eq(Money.new(250))
      expect(detail_row[:facility]).to eq(Money.new(0))
      expect(detail_row[:processing]).to eq(Money.new(39))
      expect(detail_row[:net]).to eq(Money.new(211))
      expect(detail_row[:max_ticket]).to eq(Money.new(600))
    end
  end

  describe 'summary row' do
    it 'totals the production figures' do
      expect(summary_row[:performance_code]).to eq(production.production_code)
      expect(summary_row[:paid]).to eq(1)
      expect(summary_row[:holds]).to eq(0)
      expect(summary_row[:gross]).to eq(Money.new(250))
      expect(summary_row[:collected]).to eq(Money.new(250))
      expect(summary_row[:facility]).to eq(Money.new(0))
      expect(summary_row[:processing]).to eq(Money.new(39))
      expect(summary_row[:net]).to eq(Money.new(211))
    end
  end
end
