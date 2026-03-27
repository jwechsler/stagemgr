require 'rails_helper'

RSpec.describe ExportSalesCountsJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:temp_dir)       { Rails.root.join('tmp', 'tests') }
  let(:last7_path)     { File.join(temp_dir, 'last7_counts.txt') }
  let(:previous7_path) { File.join(temp_dir, 'previous7_counts.txt') }

  let!(:production_a) { FactoryBot.create(:production, name: 'Alpha Show') }
  let!(:production_b) { FactoryBot.create(:production, name: 'Beta Show') }

  before { FileUtils.mkdir_p(temp_dir) }
  after  { FileUtils.rm_rf(temp_dir) }

  # Helper: build a RateOfSale record directly (no factory exists yet)
  def create_rate_of_sale(production:, day_of_sale:, order_count: 2,
                          total_single_tickets: 3, total_complimentary_tickets: 1,
                          gross_sales: 30.00, processing_fees: 1.50)
    RateOfSale.create!(
      production:                  production,
      day_of_sale:                 day_of_sale,
      order_count:                 order_count,
      total_single_tickets:        total_single_tickets,
      total_complimentary_tickets: total_complimentary_tickets,
      gross_sales:                 gross_sales,
      processing_fees:             processing_fees
    )
  end

  describe '.perform' do
    context "with period 'last7'" do
      before do
        # Two records in range, one outside
        create_rate_of_sale(production: production_a, day_of_sale: 3.days.ago.to_date,
                            order_count: 5, total_single_tickets: 10,
                            total_complimentary_tickets: 2, gross_sales: 100.00)
        create_rate_of_sale(production: production_b, day_of_sale: Date.yesterday,
                            order_count: 3, total_single_tickets: 6,
                            total_complimentary_tickets: 0, gross_sales: 60.00)
        # Outside range (8 days ago)
        create_rate_of_sale(production: production_a, day_of_sale: 8.days.ago.to_date,
                            order_count: 1, total_single_tickets: 2,
                            total_complimentary_tickets: 0, gross_sales: 20.00)

        ExportSalesCountsJob.perform('last7', last7_path)
      end

      it 'writes to last7_counts.txt' do
        expect(File).to exist(last7_path)
      end

      it 'reads records in the 7-days-ago..yesterday range' do
        content = File.read(last7_path)
        expect(content).to include('Alpha Show')
        expect(content).to include('Beta Show')
      end

      it 'excludes records outside the date range' do
        content = File.read(last7_path)
        # Alpha Show should have order_count=5 (not 5+1=6 from outside-range record)
        expect(content).to match(/Alpha Show\s*\|\s*5\s*\|/)
      end

      it 'aggregates order_count by production' do
        content = File.read(last7_path)
        expect(content).to match(/Alpha Show\s*\|\s*5\s*\|/)
        expect(content).to match(/Beta Show\s*\|\s*3\s*\|/)
      end

      it 'aggregates num_sold (single + comp tickets) by production' do
        content = File.read(last7_path)
        # Alpha: 10 + 2 = 12
        expect(content).to match(/Alpha Show\s*\|\s*5\s*\|\s*12\s*\|/)
        # Beta: 6 + 0 = 6
        expect(content).to match(/Beta Show\s*\|\s*3\s*\|\s*6\s*\|/)
      end

      it 'formats currency with 2 decimal places' do
        content = File.read(last7_path)
        expect(content).to include('100.00')
        expect(content).to include('60.00')
      end

      it 'has no title line (content starts with separator)' do
        content = File.read(last7_path)
        expect(content).to start_with('+')
      end

      it 'has no footer line (last line is a separator)' do
        content = File.read(last7_path)
        expect(content.split("\n").last).to start_with('+')
      end

      it 'sorts rows alphabetically by production name' do
        content = File.read(last7_path)
        alpha_pos = content.index('Alpha Show')
        beta_pos  = content.index('Beta Show')
        expect(alpha_pos).to be < beta_pos
      end
    end

    context "with period 'previous7'" do
      before do
        # Record in previous7 range (14..8 days ago)
        create_rate_of_sale(production: production_a, day_of_sale: 10.days.ago.to_date,
                            order_count: 4, total_single_tickets: 8,
                            total_complimentary_tickets: 1, gross_sales: 80.00)
        # Record outside previous7 range (yesterday)
        create_rate_of_sale(production: production_b, day_of_sale: Date.yesterday,
                            order_count: 2, total_single_tickets: 4,
                            total_complimentary_tickets: 0, gross_sales: 40.00)

        ExportSalesCountsJob.perform('previous7', previous7_path)
      end

      it 'writes to previous7_counts.txt' do
        expect(File).to exist(previous7_path)
      end

      it 'reads records from 14-days-ago..8-days-ago range' do
        content = File.read(previous7_path)
        expect(content).to include('Alpha Show')
        expect(content).not_to include('Beta Show')
      end
    end

    context 'production name truncation' do
      let!(:long_name_production) do
        FactoryBot.create(:production, name: 'A Very Long Production Name That Exceeds Limit')
      end

      before do
        create_rate_of_sale(production: long_name_production, day_of_sale: 3.days.ago.to_date)
        ExportSalesCountsJob.perform('last7', last7_path)
      end

      it 'truncates production names to 24 characters' do
        content = File.read(last7_path)
        expect(content).to include('A Very Long Production N')
        expect(content).not_to include('A Very Long Production Name That Exceeds Limit')
      end
    end

    context 'currency formatting' do
      before do
        create_rate_of_sale(production: production_a, day_of_sale: 3.days.ago.to_date,
                            gross_sales: 4803.80)
        ExportSalesCountsJob.perform('last7', last7_path)
      end

      it 'adds comma thousands separators' do
        content = File.read(last7_path)
        expect(content).to include('4,803.80')
      end
    end

    context 'with multiple records for the same production' do
      before do
        create_rate_of_sale(production: production_a, day_of_sale: 5.days.ago.to_date,
                            order_count: 3, total_single_tickets: 5,
                            total_complimentary_tickets: 1, gross_sales: 50.00)
        create_rate_of_sale(production: production_a, day_of_sale: 3.days.ago.to_date,
                            order_count: 2, total_single_tickets: 4,
                            total_complimentary_tickets: 0, gross_sales: 40.00)
        ExportSalesCountsJob.perform('last7', last7_path)
      end

      it 'aggregates multiple records for the same production into one row' do
        content = File.read(last7_path)
        # Should appear only once
        expect(content.scan('Alpha Show').length).to eq(1)
        # orders: 3 + 2 = 5
        expect(content).to match(/Alpha Show\s*\|\s*5\s*\|/)
        # num_sold: (5+1) + (4+0) = 10
        expect(content).to match(/Alpha Show\s*\|\s*5\s*\|\s*10\s*\|/)
        # amount: 50.00 + 40.00 = 90.00
        expect(content).to include('90.00')
      end
    end

    context 'with an unknown period' do
      it 'raises ArgumentError' do
        expect { ExportSalesCountsJob.perform('weekly') }.to raise_error(ArgumentError, /Unknown period: weekly/)
      end
    end
  end
end
