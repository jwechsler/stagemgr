require 'rails_helper'

# Picker for non-seat-holding ticket classes on reserved-seating order forms,
# shared by the public flow and the box office. It is the inverse of the
# seat-click modal: ONLY classes with holds_seats == false appear, gated by the
# same web_visible / :view_backend_classes rule as the modal.
RSpec.describe 'seat_assignments/_non_seat_ticket_picker', type: :view do
  def ticket_class(class_name:, web_visible: true, holds_seats: false, ticket_type: 'Fixed')
    tc = TicketClass.new(
      class_code: class_name.upcase.delete(' '), class_name: class_name,
      ticket_price: 15, ticket_type: ticket_type, web_visible: web_visible,
      software_managed: false, hide_pricing: false, zone_id: '*',
      holds_seats: holds_seats
    )
    allow(tc).to receive(:id).and_return(rand(10_000))
    tc
  end

  def allocation(tkt_class)
    tca = TicketClassAllocation.new
    allow(tca).to receive(:available?).and_return(true)
    allow(tca).to receive(:ticket_class).and_return(tkt_class)
    tca
  end

  def render_picker(classes, can_view_backend: false)
    performance = instance_double(Performance, ticket_class_allocations: classes.map { |tc| allocation(tc) })
    order = double('order', performance: performance, performance_id: 1, uuid: 'test-uuid')
    order_form = double('order_form', object: order)

    allow(view).to receive(:can?).with(:view_backend_classes, TicketClassAllocation)
                                 .and_return(can_view_backend)

    render partial: 'seat_assignments/non_seat_ticket_picker', locals: { order_form: order_form }
  end

  it 'lists only classes that do not hold seats' do
    render_picker([ticket_class(class_name: 'Hearing Assist', holds_seats: false),
                   ticket_class(class_name: 'General Admission', holds_seats: true)])

    expect(rendered).to include('Hearing Assist')
    expect(rendered).not_to include('General Admission')
  end

  it 'hides non-web-visible classes from the public flow' do
    render_picker([ticket_class(class_name: 'Crew Comp', web_visible: false)], can_view_backend: false)

    expect(rendered).not_to include('Crew Comp')
    expect(rendered).to include('display:none')
  end

  it 'shows non-web-visible classes to box office staff' do
    render_picker([ticket_class(class_name: 'Crew Comp', web_visible: false)], can_view_backend: true)

    expect(rendered).to include('Crew Comp')
  end

  it 'hides the whole section when no classes are eligible' do
    render_picker([ticket_class(class_name: 'General Admission', holds_seats: true)])

    expect(rendered).to include('display:none')
  end

  it 'renders a donation override input for Donation classes' do
    render_picker([ticket_class(class_name: 'Meal Donation', ticket_type: 'Donation')])

    expect(rendered).to include('donation-price-override')
  end

  it 'renders an Add button carrying the ticket class id' do
    tc = ticket_class(class_name: 'Hearing Assist')
    render_picker([tc])

    expect(rendered).to include('non-seat-add-button')
    expect(rendered).to include("data-ticket-class=\"#{tc.id}\"")
  end
end
