# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateOfSale, type: :model do
  let(:production) { FactoryBot.create(:production) }

  # ---------------------------------------------------------------------------
  # Factory/default helpers
  # ---------------------------------------------------------------------------
  def build_ros(overrides = {})
    RateOfSale.new({
      day_of_sale: Date.current,
      production: production,
      total_single_tickets: 5,
      total_complimentary_tickets: 2,
      gross_sales: BigDecimal('50.00'),
      processing_fees: BigDecimal('1.50'),
      order_count: 3
    }.merge(overrides))
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe 'validations' do
    it 'is valid with all required attributes' do
      expect(build_ros).to be_valid
    end

    it 'requires day_of_sale' do
      ros = build_ros(day_of_sale: nil)
      expect(ros).not_to be_valid
      expect(ros.errors[:day_of_sale]).not_to be_empty
    end

    it 'requires production' do
      ros = build_ros(production: nil)
      expect(ros).not_to be_valid
      expect(ros.errors[:production]).not_to be_empty
    end

    it 'requires total_single_tickets to be a non-negative integer' do
      expect(build_ros(total_single_tickets: 0)).to be_valid
      expect(build_ros(total_single_tickets: -1)).not_to be_valid
    end

    it 'requires total_complimentary_tickets to be a non-negative integer' do
      expect(build_ros(total_complimentary_tickets: 0)).to be_valid
      expect(build_ros(total_complimentary_tickets: -1)).not_to be_valid
    end

    it 'requires gross_sales to be >= 0' do
      expect(build_ros(gross_sales: 0)).to be_valid
      expect(build_ros(gross_sales: -1)).not_to be_valid
    end

    it 'requires processing_fees to be present' do
      ros = build_ros(processing_fees: nil)
      expect(ros).not_to be_valid
      expect(ros.errors[:processing_fees]).not_to be_empty
    end

    it 'requires order_count to be a non-negative integer' do
      expect(build_ros(order_count: 0)).to be_valid
      expect(build_ros(order_count: -1)).not_to be_valid
    end

    it 'requires total_single_tickets to be an integer (rejects fractional)' do
      # NOTE: SQLite stores decimals as strings and may coerce — this tests model validation
      ros = build_ros(total_single_tickets: 2.5)
      expect(ros).not_to be_valid
    end

    it 'requires total_complimentary_tickets to be an integer (rejects fractional)' do
      ros = build_ros(total_complimentary_tickets: 1.7)
      expect(ros).not_to be_valid
    end

    it 'requires order_count to be an integer (rejects fractional)' do
      ros = build_ros(order_count: 1.5)
      expect(ros).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  describe 'associations' do
    it 'belongs to a production' do
      ros = build_ros
      ros.save!
      expect(ros.production).to eq(production)
    end

    it 'has a theater through production' do
      ros = build_ros
      ros.save!
      expect(ros.theater).to eq(production.theater)
    end
  end

  # ---------------------------------------------------------------------------
  # .export_columns
  # ---------------------------------------------------------------------------
  describe '.export_columns' do
    subject(:cols) { RateOfSale.export_columns }

    it 'returns a Hash' do
      expect(cols).to be_a(Hash)
    end

    it 'includes the expected column keys' do
      expect(cols).to have_key(:day_of_sale)
      expect(cols).to have_key(:production)
      expect(cols).to have_key(:total_single_tickets)
      expect(cols).to have_key(:total_complimentary_tickets)
      expect(cols).to have_key(:gross_sales)
      expect(cols).to have_key(:processing_fees)
      expect(cols).to have_key(:order_count)
    end

    it 'maps column keys to human-readable headers' do
      expect(cols[:day_of_sale]).to eq('Date')
      expect(cols[:production]).to eq('Production')
      expect(cols[:total_single_tickets]).to eq('Tickets')
      expect(cols[:total_complimentary_tickets]).to eq('Comps')
      expect(cols[:gross_sales]).to eq('Total')
      expect(cols[:processing_fees]).to eq('Fees')
      expect(cols[:order_count]).to eq('Orders')
    end
  end

  # ---------------------------------------------------------------------------
  # .export_records
  # ---------------------------------------------------------------------------
  describe '.export_records' do
    it 'returns records where day_of_sale is in the prior 8-day window (yesterday - 7 through yesterday)' do
      yesterday = Date.yesterday
      eight_days_ago = yesterday - 7.days

      # A record inside the window
      inside = RateOfSale.create!(
        day_of_sale: yesterday,
        production: production,
        total_single_tickets: 1, total_complimentary_tickets: 0,
        gross_sales: 10.00, processing_fees: 0.00, order_count: 1
      )

      # A record outside the window (too old)
      too_old = RateOfSale.create!(
        day_of_sale: eight_days_ago - 1.day,
        production: production,
        total_single_tickets: 2, total_complimentary_tickets: 0,
        gross_sales: 20.00, processing_fees: 0.00, order_count: 1
      )

      # A record outside the window (today/future — should be excluded).
      # Date.current keeps this in the app time zone like Date.yesterday
      # above; Date.today (system zone) collides with it on late-evening
      # runs from a zone west of Central.
      today_record = RateOfSale.create!(
        day_of_sale: Date.current,
        production: production,
        total_single_tickets: 3, total_complimentary_tickets: 0,
        gross_sales: 30.00, processing_fees: 0.00, order_count: 1
      )

      records = RateOfSale.export_records
      expect(records).to include(inside)
      expect(records).not_to include(too_old)
      expect(records).not_to include(today_record)
    end

    it 'includes the boundary dates (eight_days_ago and yesterday)' do
      yesterday = Date.yesterday
      eight_days_ago = yesterday - 7.days

      boundary_start = RateOfSale.create!(
        day_of_sale: eight_days_ago,
        production: production,
        total_single_tickets: 1, total_complimentary_tickets: 0,
        gross_sales: 10.00, processing_fees: 0.00, order_count: 1
      )

      boundary_end = RateOfSale.create!(
        day_of_sale: yesterday,
        production: production,
        total_single_tickets: 1, total_complimentary_tickets: 0,
        gross_sales: 10.00, processing_fees: 0.00, order_count: 1
      )

      records = RateOfSale.export_records
      expect(records).to include(boundary_start)
      expect(records).to include(boundary_end)
    end

    it 'returns an empty relation when there are no records in the window' do
      expect(RateOfSale.export_records).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # MetricsExporter concern (exercised via RateOfSale)
  # ---------------------------------------------------------------------------
  describe '.export_to_file via MetricsExporter' do
    let(:tmpfile) { Tempfile.new(['rate_of_sales', '.txt']) }
    after do
      tmpfile.close
      tmpfile.unlink
    end

    it 'writes a file with header, separator, and record lines' do
      RateOfSale.create!(
        day_of_sale: Date.yesterday,
        production: production,
        total_single_tickets: 5, total_complimentary_tickets: 1,
        gross_sales: 75.00, processing_fees: 2.50, order_count: 3
      )

      records = RateOfSale.export_records
      columns = RateOfSale.export_columns
      RateOfSale.export_to_file(records, columns, tmpfile.path)

      content = File.read(tmpfile.path)
      expect(content).to include('Date')
      expect(content).to include('Tickets')
      expect(content).to include('|')
    end
  end
end
