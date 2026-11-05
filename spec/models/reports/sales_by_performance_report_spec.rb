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
      # Canonical vocabulary: the old :gross column is now :revenue_collected
      # ("Revenue Collected"), and the old :collected column is now :reportable.
      # Column order is unchanged.
      expect(headers.last(8)).to eq(%i[paid holds max_ticket revenue_collected reportable facility processing net])
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
      expect(detail_row[:revenue_collected]).to eq(Money.new(250))
      expect(detail_row[:reportable]).to eq(Money.new(250))
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
      expect(summary_row[:revenue_collected]).to eq(Money.new(250))
      expect(summary_row[:reportable]).to eq(Money.new(250))
      expect(summary_row[:facility]).to eq(Money.new(0))
      expect(summary_row[:processing]).to eq(Money.new(39))
      expect(summary_row[:net]).to eq(Money.new(211))
    end
  end
  describe 'with several performances, settled orders and held orders' do
    # A second performance on another day, so the two never share a 15-minute
    # time block.
    let(:second_performance) do
      FactoryBot.create(:performance, production: production, performance_date: Date.current + 1)
    end

    def add_settled_orders(perf, count)
      FactoryBot.create_list(:ticket_order, count, :for_a_pair_of_tickets, :paid_with_credit_card, performance: perf)
    end

    def add_held_order(perf)
      FactoryBot.create(:ticket_order, :for_a_single_ticket, performance: perf, status: Order::HOLD)
    end

    def queries_during_create
      report = described_class.new([production.id])
      count = 0
      counter = lambda do |_name, _start, _finish, _id, payload|
        next if %w[SCHEMA TRANSACTION CACHE].include?(payload[:name]) || payload[:cached]

        count += 1
      end
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { report.create }
      count
    end

    def row_for(perf)
      described_class.new([production.id]).create[1].find { |r| r[:performance_code] == perf.performance_code }
    end

    before do
      [performance, second_performance].each do |perf|
        add_settled_orders(perf, 3)
        add_held_order(perf)
      end
    end

    it 'runs the same number of queries regardless of how many orders each performance has' do
      baseline = queries_during_create

      [performance, second_performance].each { |perf| add_settled_orders(perf, 3) }

      expect(queries_during_create).to eq(baseline)
    end

    it 'counts paid and held tickets per performance row' do
      # performance: the outer single-ticket order plus three pairs; one held single.
      expect(row_for(performance)).to include(paid: 7, holds: 1)
      # second_performance: three pairs; one held single.
      expect(row_for(second_performance)).to include(paid: 6, holds: 1)
    end
  end
end
