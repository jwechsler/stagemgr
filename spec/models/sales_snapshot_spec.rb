# frozen_string_literal: true

require 'rails_helper'

# SalesSnapshot is a thin model: it belongs_to :production_stat and stores
# a daily snapshot of advance sales data (advance_sales, advance_seats,
# daily_sales, sales_to_date, seats_to_date).
#
# SUSPECTED BUG (sales_snapshot.rb:2 / belongs_to :production_stat):
#   The ProductionStat model class no longer exists as an ActiveRecord model.
#   Any attempt to save! (or valid?) a SalesSnapshot raises:
#     NameError: uninitialized constant SalesSnapshot::ProductionStat
#   This is the CURRENT behavior being pinned down — not a desirable design.
#   The FK column and belongs_to declaration remain as orphans from a removed model.
RSpec.describe SalesSnapshot, type: :model do
  # ---------------------------------------------------------------------------
  # Persistence (using save(validate: false) because belongs_to raises NameError)
  # ---------------------------------------------------------------------------
  describe 'persistence' do
    it 'can be saved when bypassing validation (insert via raw SQL path)' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      snapshot.save(validate: false)
      expect(snapshot.persisted?).to be true
    end

    it 'stores and retrieves numeric fields correctly when saved without validation' do
      snapshot = SalesSnapshot.new(
        as_of_date: Date.today,
        advance_sales: 250.75,
        advance_seats: 10,
        daily_sales: 50.00,
        sales_to_date: 1000.50,
        seats_to_date: 40
      )
      snapshot.save(validate: false)
      reloaded = SalesSnapshot.find(snapshot.id)
      expect(reloaded.advance_sales.to_f).to be_within(0.01).of(250.75)
      expect(reloaded.advance_seats).to eq(10)
      expect(reloaded.daily_sales.to_f).to be_within(0.01).of(50.00)
      expect(reloaded.sales_to_date.to_f).to be_within(0.01).of(1000.50)
      expect(reloaded.seats_to_date).to eq(40)
    end
  end

  # ---------------------------------------------------------------------------
  # Default values from the schema
  # ---------------------------------------------------------------------------
  describe 'default values' do
    it 'defaults advance_sales to 0.0' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect(snapshot.advance_sales.to_f).to eq(0.0)
    end

    it 'defaults advance_seats to 0' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect(snapshot.advance_seats.to_i).to eq(0)
    end

    it 'defaults daily_sales to 0.0' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect(snapshot.daily_sales.to_f).to eq(0.0)
    end

    it 'defaults sales_to_date to 0.0' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect(snapshot.sales_to_date.to_f).to eq(0.0)
    end

    it 'defaults seats_to_date to 0' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect(snapshot.seats_to_date.to_i).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # Association: belongs_to :production_stat  (SUSPECTED BUG)
  # ---------------------------------------------------------------------------
  describe 'associations' do
    it 'responds to production_stat' do
      snapshot = SalesSnapshot.new
      expect(snapshot).to respond_to(:production_stat)
    end

    it 'responds to production_stat_id' do
      snapshot = SalesSnapshot.new
      expect(snapshot).to respond_to(:production_stat_id)
    end

    # SUSPECTED BUG: belongs_to :production_stat references a model class
    # (ProductionStat) that no longer exists. Saving raises NameError.
    # This test pins down the current broken behavior.
    it 'raises NameError when attempting save! because ProductionStat class is missing' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect { snapshot.save! }.to raise_error(NameError, /ProductionStat/)
    end

    it 'raises NameError even with valid? because belongs_to triggers reflection lookup' do
      snapshot = SalesSnapshot.new(as_of_date: Date.today)
      expect { snapshot.valid? }.to raise_error(NameError, /ProductionStat/)
    end
  end

  # ---------------------------------------------------------------------------
  # Factory sanity check
  # ---------------------------------------------------------------------------
  describe 'factory' do
    it 'builds a SalesSnapshot object via factory' do
      snapshot = FactoryBot.build(:sales_snapshot, production_stat_id: nil)
      expect(snapshot).to be_a(SalesSnapshot)
      expect(snapshot.as_of_date).to be_present
    end
  end
end
