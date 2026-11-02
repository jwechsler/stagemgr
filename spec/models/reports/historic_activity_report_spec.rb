require 'rails_helper'

RSpec.describe HistoricActivityReport, type: :model do
  let(:start_day) { Date.current - 30 }
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production, performance_date: Date.current - 7) }

  def attended_order(address, paid:)
    order = FactoryBot.create(:ticket_order, address: address, performance: performance)
    order.update_columns(status: Order::FULFILLED)
    FactoryBot.create(:cash_payment, order: order, amount: paid)
    order
  end

  def run_report(minimum_revenue = 0.0)
    report = described_class.new(start_day, 0, [], minimum_revenue)
    allow(report).to receive(:save_report_to_filestore) # bypass IO
    report.create
    report
  end

  def reported_address_ids(minimum_revenue)
    run_report(minimum_revenue).data['ALL'].map { |row| row[:StagemgrPatronID] }
  end

  it 'runs end to end, adding its columns to the TRG headers once and filling a row per patron' do
    patron = FactoryBot.create(:address)
    attended_order(patron, paid: 30.00)

    report = run_report

    expect(report.headers).to eq(MailingList::TRG_IMPORT_HEADERS + %i[PrimaryTheatreAttendee LastAttended
                                                                      AttendedInPeriod TotalAttended
                                                                      CompaniesAttendedInPeriod
                                                                      TotalCompaniesAttended IsMember
                                                                      IsFlexPassHolder ProductionHistory])
    row = report.data['ALL'].find { |r| r[:StagemgrPatronID] == patron.id }
    expect(row[:LastAttended]).to eq(performance.performance_date)
    expect(row[:AttendedInPeriod]).to eq(1)
  end

  it "keeps patrons by their own revenue against minimum_revenue, not the house's" do
    big_spender = FactoryBot.create(:address)
    small_spender = FactoryBot.create(:address)
    attended_order(big_spender, paid: 120.00)
    attended_order(small_spender, paid: 20.00)

    ids = reported_address_ids(50.0)

    expect(ids).to include(big_spender.id)
    expect(ids).not_to include(small_spender.id)
  end
end
