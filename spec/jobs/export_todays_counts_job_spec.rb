# ./spec/jobs/export_todays_counts_job_spec.rb

require 'rails_helper'

RSpec.describe ExportTodaysCountsJob, type: :job do
  let(:temp_dir) { Rails.root.join('tmp/tests') }
  let(:file_path) { File.join(temp_dir, 'todays_counts.txt') }

  before do
    FileUtils.mkdir_p(temp_dir)
    allow($SERVER_CONFIG).to receive(:[]).and_call_original
    allow($SERVER_CONFIG).to receive(:[]).with('hud_export_directory').and_return(temp_dir.to_s)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  def create_rate_of_sale(production:, day_of_sale: Date.current, **attrs)
    RateOfSale.create!(
      {
        production: production,
        day_of_sale: day_of_sale,
        total_single_tickets: 0,
        total_complimentary_tickets: 0,
        gross_sales: 0,
        processing_fees: 0,
        order_count: 0
      }.merge(attrs)
    )
  end

  describe '.perform' do
    context 'with RateOfSale records for today' do
      let!(:production) { FactoryBot.create(:production, name: 'Morning, Noon, and Night') }
      let!(:rate_of_sale) do
        create_rate_of_sale(
          production: production,
          total_single_tickets: 10,
          total_complimentary_tickets: 2,
          gross_sales: 4803.80,
          processing_fees: 12.50,
          order_count: 7
        )
      end

      before { ExportTodaysCountsJob.perform }

      it 'writes the output file to the configured hud_export_directory' do
        expect(File.exist?(file_path)).to be true
      end

      it 'includes the correct column headers' do
        content = File.read(file_path)
        expect(content).to include('sold_on')
        expect(content).to include('name')
        expect(content).to include('orders')
        expect(content).to include('num_sold')
        expect(content).to include('Amount')
      end

      it 'includes today\'s date in the sold_on column' do
        content = File.read(file_path)
        expect(content).to include(Date.current.strftime('%Y-%m-%d'))
      end

      it 'includes the order count' do
        content = File.read(file_path)
        expect(content).to include('7')
      end

      it 'sums single and complimentary tickets into num_sold' do
        content = File.read(file_path)
        expect(content).to include('12')
      end

      it 'formats the gross_sales amount as currency with commas' do
        content = File.read(file_path)
        expect(content).to include('4,803.80')
      end

      it 'includes a Generated footer line' do
        content = File.read(file_path)
        expect(content).to include('Generated ')
      end
    end

    context 'when no RateOfSale records exist for today' do
      it 'writes a file with only headers and no data rows' do
        ExportTodaysCountsJob.perform
        content = File.read(file_path)
        expect(content).to include('sold_on')
        # Only three separator+header lines; no production name rows
        lines = content.split("\n").select { |l| l.start_with?('|') }
        expect(lines.length).to eq(1) # header row only
      end
    end

    context 'when RateOfSale records exist for other dates' do
      let!(:production) { FactoryBot.create(:production, name: 'Ally') }

      before do
        create_rate_of_sale(
          production: production,
          day_of_sale: Date.current - 1.day,
          total_single_tickets: 5,
          total_complimentary_tickets: 0,
          gross_sales: 100.00,
          processing_fees: 2.00,
          order_count: 3
        )
      end

      it 'does not include records from other days' do
        ExportTodaysCountsJob.perform
        content = File.read(file_path)
        # The date from yesterday should not appear
        expect(content).not_to include((Date.current - 1.day).strftime('%Y-%m-%d'))
      end
    end

    context 'production name truncation' do
      let!(:long_name_production) do
        FactoryBot.create(:production, name: 'A Very Long Production Name That Exceeds Limit')
      end

      before do
        create_rate_of_sale(production: long_name_production, order_count: 1, gross_sales: 20.00, processing_fees: 0)
        ExportTodaysCountsJob.perform
      end

      it 'truncates production names to 24 characters' do
        content = File.read(file_path)
        expect(content).to include('A Very Long Production N')
        expect(content).not_to include('A Very Long Production Name That Exceeds Limit')
      end
    end

    context 'ordering' do
      let!(:prod_zebra) { FactoryBot.create(:production, name: 'Zebra Show') }
      let!(:prod_alpha) { FactoryBot.create(:production, name: 'Alpha Show') }

      before do
        create_rate_of_sale(production: prod_zebra, order_count: 1, gross_sales: 50.00, processing_fees: 0)
        create_rate_of_sale(production: prod_alpha, order_count: 2, gross_sales: 75.00, processing_fees: 0)
        ExportTodaysCountsJob.perform
      end

      it 'orders rows alphabetically by production name' do
        content = File.read(file_path)
        alpha_pos = content.index('Alpha Show')
        zebra_pos = content.index('Zebra Show')
        expect(alpha_pos).to be < zebra_pos
      end
    end
  end

  describe '.format_currency' do
    it 'formats amounts below 1000 with two decimal places and no comma' do
      expect(ExportTodaysCountsJob.format_currency(20.0)).to eq('20.00')
    end

    it 'formats amounts above 1000 with comma thousands separator' do
      expect(ExportTodaysCountsJob.format_currency(4803.80)).to eq('4,803.80')
    end

    it 'formats amounts above 1,000,000 with two commas' do
      expect(ExportTodaysCountsJob.format_currency(1_234_567.89)).to eq('1,234,567.89')
    end

    it 'rounds to two decimal places' do
      expect(ExportTodaysCountsJob.format_currency(9.999)).to eq('10.00')
    end

    it 'formats zero correctly' do
      expect(ExportTodaysCountsJob.format_currency(0)).to eq('0.00')
    end
  end
end
