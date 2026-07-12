require 'rails_helper'

RSpec.describe ProductionAttendeeReport, type: :model do
  let(:reporting_user) { FactoryBot.create(:admin_user) }
  let(:theater)        { FactoryBot.create(:theater) }
  let(:festival)       { FactoryBot.create(:festival, name: 'Physical Theatre Festival') }

  let(:production_a) do
    FactoryBot.create(:production, theater: theater, name: 'Gravity', festival: festival)
  end
  let(:production_b) do
    FactoryBot.create(:production, theater: theater, name: 'Momentum', festival: festival)
  end

  let(:performance_a) { FactoryBot.create(:performance, production: production_a) }
  let(:performance_b) { FactoryBot.create(:performance, production: production_b) }

  let!(:order_a) do
    FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card,
                      performance: performance_a)
  end
  let!(:order_b) do
    FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card,
                      performance: performance_b)
  end

  def order_ids(report)
    report.create
    report.data.map { |row| row[:id] }
  end

  describe 'production selection' do
    it 'includes orders from every selected production' do
      report = described_class.new([production_a.id, production_b.id], false, reporting_user.id)
      expect(order_ids(report)).to contain_exactly(order_a.id, order_b.id)
    end

    it 'accepts a legacy scalar production id (Array normalization)' do
      report = described_class.new(production_a.id, false, reporting_user.id)
      expect(order_ids(report)).to contain_exactly(order_a.id)
    end
  end

  describe 'reserved-seating column' do
    it 'omits the seat_assignments column for general-admission productions' do
      report = described_class.new([production_a.id, production_b.id], false, reporting_user.id)
      expect(report.headers).not_to include(:seat_assignments)
    end
  end

  describe 'export filename' do
    it 'uses the single production name unchanged' do
      report = described_class.new([production_a.id], false, reporting_user.id)
      expect(report.send(:export_filename)).to eq("Gravity-attendees-#{reporting_user.id}.csv")
    end

    it 'uses the shared festival name when all productions share one festival' do
      report = described_class.new([production_a.id, production_b.id], false, reporting_user.id)
      expect(report.send(:export_filename))
        .to eq("Physical_Theatre_Festival-attendees-#{reporting_user.id}.csv")
    end

    it 'falls back to a generic label for productions without a shared festival' do
      loose = FactoryBot.create(:production, theater: theater, name: 'Solo')
      report = described_class.new([production_a.id, loose.id], false, reporting_user.id)
      expect(report.send(:export_filename)).to eq("selected-productions-attendees-#{reporting_user.id}.csv")
    end
  end
end
