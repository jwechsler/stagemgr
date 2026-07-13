require 'rails_helper'

RSpec.describe PerformancesController, type: :controller do
  describe 'GET ticket_classes (json)' do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance) do
      FactoryBot.create(:reserved_seating, production: production,
                                           performance_date: Date.today + 1.day,
                                           performance_time: Time.parse('19:00'))
    end

    it 'includes holds_seats so the client can split seat-modal vs picker classes' do
      addon = FactoryBot.create(:ticket_class, production: production, holds_seats: false,
                                               class_name: 'Hearing Assist')
      tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: addon)
      tca.available = true
      tca.save!

      get :ticket_classes, params: { id: performance.id }, format: :json
      expect(response).to be_successful
      result = response.parsed_body

      expect(result).not_to be_empty
      expect(result).to all(have_key('holds_seats'))
      addon_row = result.find { |r| r['id'] == addon.id }
      expect(addon_row['holds_seats']).to eq(false)
    end
  end
end
