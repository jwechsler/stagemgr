require 'rails_helper'

RSpec.describe CustomerMailingList, type: :model do
  let(:start_day) { Date.current - 30 }
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production, performance_date: Date.current - 7) }

  # ticket_class find_or_create ignores production, so give every class its own code.
  def ticket_class_for(perf, complimentary: false)
    FactoryBot.create(:ticket_class, production: perf.production, complimentary: complimentary,
                                     class_code: "CML#{SecureRandom.hex(3).upcase}")
  end

  def attended_order(address, paid: 30.00, perf: performance, complimentary: false)
    order = FactoryBot.create(:ticket_order, address: address, performance: perf)
    TicketLineItem.create!(order: order, ticket_class: ticket_class_for(perf, complimentary: complimentary),
                           ticket_count: 1)
    order.update_columns(status: Order::FULFILLED)
    FactoryBot.create(:cash_payment, order: order, amount: paid) if paid.positive?
    order
  end

  def run_report(minimum_attended: 0, minimum_revenue: 0.0)
    report = described_class.new(minimum_attended, minimum_revenue, start_day)
    allow(report).to receive(:save_report_to_filestore) # bypass IO
    report.create
    report
  end

  def reported_address_ids(**thresholds)
    run_report(**thresholds).data['LST'].map { |row| row[:StagemgrPatronID] }
  end

  it 'runs end to end, filling a row for a patron with a paid ticket order in the period' do
    patron = FactoryBot.create(:address)
    attended_order(patron)

    row = run_report.data['LST'].find { |r| r[:StagemgrPatronID] == patron.id }

    expect(row[:LastAttended]).to eq(performance.performance_date)
    expect(row[:AttendedInPeriod]).to eq(1)
    expect(row[:IsFlexPassHolder]).to eq('N')
  end

  it 'flags a patron holding an active flex pass' do
    patron = FactoryBot.create(:address)
    attended_order(patron)
    FactoryBot.create(:flex_pass_order, address: patron)

    row = run_report.data['LST'].find { |r| r[:StagemgrPatronID] == patron.id }

    expect(row[:IsFlexPassHolder]).to eq('Y')
  end

  it "keeps patrons by their own revenue against minimum_revenue" do
    big_spender = FactoryBot.create(:address)
    small_spender = FactoryBot.create(:address)
    attended_order(big_spender, paid: 120.00)
    attended_order(small_spender, paid: 20.00)

    ids = reported_address_ids(minimum_revenue: 50.0)

    expect(ids).to include(big_spender.id)
    expect(ids).not_to include(small_spender.id)
  end

  it 'keeps patrons who attended at least minimum_attended productions in the period' do
    other_performance = FactoryBot.create(:performance, production: FactoryBot.create(:production),
                                                        performance_date: Date.current - 3)
    regular = FactoryBot.create(:address)
    one_timer = FactoryBot.create(:address)
    attended_order(regular)
    attended_order(regular, perf: other_performance)
    attended_order(one_timer)

    ids = reported_address_ids(minimum_attended: 2)

    expect(ids).to include(regular.id)
    expect(ids).not_to include(one_timer.id)
  end

  it 'excludes a patron whose only tickets are complimentary' do
    comp_patron = FactoryBot.create(:address)
    attended_order(comp_patron, paid: 0, complimentary: true)

    expect(reported_address_ids).not_to include(comp_patron.id)
  end

  it 're-raises a failure instead of returning a backtrace' do
    report = described_class.new(0, 0.0, start_day)
    allow(report).to receive(:save_report_to_filestore).and_raise(StandardError, 'disk full')

    expect { report.create }.to raise_error(StandardError, 'disk full')
  end
end
