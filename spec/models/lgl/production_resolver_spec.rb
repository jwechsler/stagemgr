# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::ProductionResolver do
  let(:order) { FactoryBot.create(:donation_order) }

  it 'returns the order production even when the campaign names a different one' do
    production = FactoryBot.create(:production, name: 'Linked Show')
    FactoryBot.create(:production, name: 'Other Show')
    order.update!(production: production, campaign: 'Other Show')
    expect(described_class.resolve(order)).to eq(production)
  end

  it 'matches a production whose name has trailing spaces' do
    production = FactoryBot.create(:production, name: 'Spacey Show  ')
    order.update!(campaign: ' Spacey Show')
    expect(described_class.resolve(order)).to eq(production)
  end

  it 'picks the most recently opened of two same-named productions' do
    newer = FactoryBot.create(:production, name: 'Revival', opening_at: Date.current - 1.year)
    FactoryBot.create(:production, name: 'Revival', opening_at: Date.current - 5.years)
    order.update!(campaign: 'Revival')
    expect(described_class.resolve(order)).to eq(newer)
  end

  it "returns nil for the 'Online' default campaign" do
    FactoryBot.create(:production, name: 'Online')
    order.update!(campaign: 'Online')
    expect(described_class.resolve(order)).to be_nil
  end

  it 'returns nil for a blank campaign' do
    order.update!(campaign: '  ')
    expect(described_class.resolve(order)).to be_nil
  end

  it 'returns nil and logs for an unknown production name' do
    order.update!(campaign: 'No Such Show')
    allow(Rails.logger).to receive(:info)
    expect(described_class.resolve(order)).to be_nil
    expect(Rails.logger).to have_received(:info)
      .with("[LGL] order ##{order.id}: no production named \"No Such Show\"; gift will carry no event")
  end
end
