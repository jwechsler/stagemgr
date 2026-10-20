# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::AddressMergesHelper, type: :helper do
  let!(:house) { Theater.default_theater || FactoryBot.create(:theater, theater_class: Theater::DEFAULT) }
  let(:address) { FactoryBot.create(:address) }

  def order_created_at(created_at)
    FactoryBot.create(:donation_order, address: address, theater: house).tap do |order|
      order.update_column(:created_at, created_at)
    end
  end

  describe '#address_merge_last_order' do
    it 'shows a dash when the customer has no orders' do
      expect(helper.address_merge_last_order(address)).to eq('—')
    end

    it "shows the newest order's date in long format, never an older one" do
      order_created_at(Time.zone.local(2025, 12, 31, 12))
      order_created_at(Time.zone.local(2026, 10, 20, 12))
      order_created_at(Time.zone.local(2026, 10, 17, 12))

      expect(helper.address_merge_last_order(address)).to eq('October 20, 2026')
    end
  end
end
