# spec/decorators/performance_decorator_spec.rb
require 'rails_helper'

RSpec.describe PerformanceDecorator do
  # The calendar tiers read the persisted HouseCount snapshot (calendar_sold_out?,
  # calendar_near_capacity?, calendar_seats_left), so each example pins the cached
  # flags directly and asserts the rendered tier.
  def decorated_performance(house_count_attrs)
    production = FactoryBot.create(:production, capacity: 50)
    # A week out so neither the past-performance nor the happening_soon? branch triggers
    performance = FactoryBot.create(:general_admission, production: production,
                                                        performance_date: Date.current + 7.days)
    performance.house_count.update!(house_count_attrs)
    performance.reload.decorate
  end

  describe '#order_link' do
    it 'renders a struck-through "Sold out!" with no order link when sold out' do
      html = decorated_performance(sold_out: true, near_capacity: true, available_seats: 0).order_link

      expect(html).to include('Sold out!')
      expect(html).to include('<del>')
      expect(html).not_to include('Limited seats')
      expect(html).not_to include('href')
    end

    it 'renders the limited-seats message when near capacity but not sold out' do
      html = decorated_performance(sold_out: false, near_capacity: true, available_seats: 5).order_link

      expect(html).to include('Limited seats remaining. Call box office')
      expect(html).not_to include('Sold out!')
    end

    it 'renders "1 ticket remaining" when exactly one seat is left' do
      html = decorated_performance(sold_out: false, near_capacity: true, available_seats: 1).order_link

      expect(html).to include('1 ticket remaining. Call box office')
    end

    it 'renders an order link when plenty of seats remain' do
      html = decorated_performance(sold_out: false, near_capacity: false, available_seats: 40).order_link

      expect(html).to include('href')
      expect(html).not_to include('Sold out!')
      expect(html).not_to include('Limited seats')
    end
  end
end
