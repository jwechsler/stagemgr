require 'rails_helper'

# Front-facing order-form line item. An inventory-consuming ticket class
# (holds_seats?) collapses its quantity dropdown to "Call" / "Sold Out" and routes
# the buyer to the box office when EITHER capacity gate fires:
#   * Performance#near_capacity?  (restrict_sales_due_to_capacity_at)
#   * Performance#happening_soon? (restrict_sales_due_to_time_at_minutes_before)
# Both gates mirror the calendar listing so a direct link is suspended the same way.
RSpec.describe 'orders/_line_item', type: :view do
  # Render the partial in isolation with a real SimpleForm builder over an
  # in-memory ticket line item, so we exercise the actual view branching.
  def render_line_item(performance:, holds_seats: true, class_ticket_count_left: 50)
    ticket_class = TicketClass.new(
      class_code: 'GEN01', class_name: 'General Admission', ticket_price: 32,
      ticket_type: 'Fixed', holds_seats: holds_seats, software_managed: false, hide_pricing: false
    )
    allow(ticket_class).to receive(:number_left).and_return(class_ticket_count_left)

    line_item = TicketLineItem.new(ticket_count: 0)
    allow(line_item).to receive(:ticket_class).and_return(ticket_class)

    builder = SimpleForm::FormBuilder.new(:ticket_order, line_item, view, {})
    render partial: 'orders/line_item', locals: { f: builder, performance: performance }
  end

  def performance_double(seats_left:, near_capacity:, happening_soon:)
    instance_double(
      Performance,
      number_of_seats_left: seats_left,
      near_capacity?: near_capacity,
      happening_soon?: happening_soon
    )
  end

  context 'when sales are open (not near capacity, not within the pre-show cutoff)' do
    it 'shows a quantity dropdown and no box-office message' do
      render_line_item(performance: performance_double(seats_left: 50, near_capacity: false, happening_soon: false))

      expect(rendered).to include('<select')
      expect(rendered).not_to include('Call')
      expect(rendered).not_to include('Sold Out')
    end
  end

  context 'capacity gate — Performance#near_capacity?' do
    it 'collapses to "Call" when near capacity with seats still remaining' do
      render_line_item(performance: performance_double(seats_left: 5, near_capacity: true, happening_soon: false))

      expect(rendered).to include('Call')
      expect(rendered).not_to include('<select')
    end

    it 'shows "Sold Out" (not "Call") when no seats remain' do
      render_line_item(performance: performance_double(seats_left: 0, near_capacity: true, happening_soon: false))

      expect(rendered).to include('Sold Out')
      expect(rendered).not_to include('Call')
      expect(rendered).not_to include('<select')
    end
  end

  context 'time gate — Performance#happening_soon?' do
    it 'collapses to "Call" within the pre-show cutoff even with plenty of seats' do
      render_line_item(performance: performance_double(seats_left: 40, near_capacity: false, happening_soon: true))

      expect(rendered).to include('Call')
      expect(rendered).not_to include('<select')
    end
  end

  context 'non-inventory ticket classes (holds_seats? == false)' do
    it 'always shows the dropdown regardless of either gate' do
      render_line_item(
        performance: performance_double(seats_left: 0, near_capacity: true, happening_soon: true),
        holds_seats: false
      )

      expect(rendered).to include('<select')
      expect(rendered).not_to include('Call')
      expect(rendered).not_to include('Sold Out')
    end
  end
end
