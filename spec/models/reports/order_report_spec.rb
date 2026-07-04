require 'rails_helper'

# Characterization spec: pins the current output of OrderReport so the upcoming
# revenue-vocabulary refactor cannot change the computed numbers.
RSpec.describe OrderReport, type: :model do
  describe '.columns_for_orders' do
    it 'returns the dumpfile column set by default' do
      columns = described_class.columns_for_orders
      # Pin the full ordered column set. The second-address column symbol is
      # mapped to a string here to avoid duplicating a numbered-symbol literal.
      expect(columns.map(&:to_s)).to eq(
        %w[order_date id first_name last_name street_address street_address_2
           city state postal_code phone performance_code special_offer_code
           status description facility_fee processing_fee]
      )
    end

    it 'returns only order_date when not building for a dumpfile' do
      expect(described_class.columns_for_orders(false)).to eq(%i[order_date])
    end

    it 'adds the email column when requested for a dumpfile' do
      expect(described_class.columns_for_orders(true, true)).to include(:email)
    end
  end

  describe '.create_hash_from_order_fields' do
    let(:production) { FactoryBot.create(:production) }
    let(:performance) { FactoryBot.create(:performance, production: production) }

    # Single $2.50 GEN01 ticket paid by credit card. Processing fee 0.39
    # (3.9%), no facility/ticketing fee. order_revenue = total_paid -
    # processing - ticketing = 2.50 - 0.39 - 0.00 = 2.11.
    let(:order) do
      FactoryBot.create(:ticket_order,
                        :for_a_single_ticket,
                        :paid_with_credit_card,
                        performance: performance)
    end

    subject(:row) { described_class.create_hash_from_order_fields(order) }

    it 'reports the order totals and per-order revenue' do
      expect(row[:status]).to eq('Processed')
      expect(row[:order_total]).to eq(Money.new(250))
      expect(row[:order_revenue]).to eq(Money.new(211))
      expect(row[:facility_fee]).to eq(Money.new(0))
      expect(row[:processing_fee]).to eq(Money.new(39))
      expect(row[:num_tickets]).to eq(1)
      expect(row[:num_seats]).to eq(1)
      expect(row[:performance_code]).to eq(performance.performance_code)
    end

    it 'includes the purchaser address fields' do
      expect(row[:last_name]).to eq(order.address.last_name)
      expect(row[:first_name]).to eq(order.address.first_name)
      expect(row[:email]).to eq(order.address.email)
    end
  end
end
