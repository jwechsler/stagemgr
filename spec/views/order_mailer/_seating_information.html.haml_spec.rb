require 'rails_helper'

# Seat sentence in the order confirmation email. Seat features are map data,
# not something the patron chose, so they are never printed.
RSpec.describe 'order_mailer/_seating_information', type: :view do
  def seat_assignment(location, feature: nil)
    seat = Seat.new(location: location, row: location[0], seat_number: location[2..].to_i, feature: feature)
    SeatAssignment.new(seat: seat)
  end

  def render_seating(seats: [], is_reserved: true, is_special_event: false, special_request: nil)
    production = instance_double(Production, has_reserved_seating?: is_reserved,
                                             treat_as_special_event?: is_special_event)
    performance = instance_double(Performance, production: production)
    order = double('order', performance: performance, seats: seats, special_request: special_request)

    render partial: 'order_mailer/seating_information', locals: { order: order }
    Capybara.string(rendered).text.squish
  end

  context 'with a reserved seating order' do
    it 'names a single seat in the singular' do
      text = render_seating(seats: [seat_assignment('A-05')])

      expect(text).to include('You have reserved seats.')
      expect(text).to include('Your seat is A-05.')
    end

    it 'lists several seats sorted, in the plural' do
      text = render_seating(seats: [seat_assignment('B-02'), seat_assignment('A-06'), seat_assignment('A-05')])

      expect(text).to include('Your seats are A-05, A-06, B-02.')
    end

    it 'says seating for this performance for a special event' do
      text = render_seating(seats: [seat_assignment('A-05')], is_special_event: true)

      expect(text).to include('seating for this performance.')
    end

    # Regression: the old partial sorted seat features and raised
    # "comparison of String with nil failed" when a feature seat and a
    # featureless seat were in the same order.
    it 'renders an order mixing a featured seat and a featureless seat and lists both' do
      seats = [seat_assignment('A-06', feature: 'Accessible'), seat_assignment('A-05')]

      text = nil
      expect { text = render_seating(seats: seats) }.not_to raise_error
      expect(text).to include('Your seats are A-05, A-06.')
    end

    it 'never prints the feature, even when every seat has one' do
      seats = [seat_assignment('A-05', feature: 'Accessible'), seat_assignment('A-06', feature: 'Accessible')]

      text = render_seating(seats: seats)

      expect(text).to include('Your seats are A-05, A-06.')
      expect(text).not_to match(/accessible/i)
    end

    it 'ignores the special request' do
      text = render_seating(seats: [seat_assignment('A-05')], special_request: 'an aisle seat')

      expect(text).not_to include('You have requested')
    end
  end

  context 'with a general admission order' do
    it 'repeats the special request' do
      text = render_seating(is_reserved: false, special_request: 'an aisle seat')

      expect(text).to eq('You have requested an aisle seat.')
    end

    it 'renders nothing without a special request' do
      expect(render_seating(is_reserved: false, special_request: '')).to eq('')
    end
  end
end
