require 'rails_helper'

# Seat-selection ticket class modal, shared by the public order flow and the
# admin (box office) order flow. Box office staff hold the
# :view_backend_classes ability and may sell classes that are hidden from the
# public purchase page (web_visible == false); the public list stays filtered.
# Mirrors the ability gate in PerformancesController#ticket_classes.
RSpec.describe 'seat_assignments/_ticket_class_selector', type: :view do
  def ticket_class(class_name:, web_visible:)
    tc = TicketClass.new(
      class_code: class_name.upcase.delete(' '), class_name: class_name,
      ticket_price: 25, ticket_type: 'Fixed', web_visible: web_visible,
      software_managed: false, hide_pricing: false, zone_id: 'A'
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

  def render_selector(can_view_backend:)
    public_class = ticket_class(class_name: 'General Admission', web_visible: true)
    backend_class = ticket_class(class_name: 'Box Office Comp', web_visible: false)

    performance = instance_double(Performance,
                                  ticket_class_allocations: [allocation(public_class), allocation(backend_class)])
    order = double('order', performance: performance, performance_id: 1, uuid: 'test-uuid')
    order_form = double('order_form', object: order)

    allow(view).to receive(:can?).with(:view_backend_classes, TicketClassAllocation)
                                 .and_return(can_view_backend)
    stub_template 'seat_assignments/_seating_config.html.haml' => ''

    render partial: 'seat_assignments/ticket_class_selector', locals: { order_form: order_form }
  end

  context 'for box office staff (can view_backend_classes)' do
    it 'lists classes that are hidden from the public purchase page' do
      render_selector(can_view_backend: true)

      expect(rendered).to include('General Admission')
      expect(rendered).to include('Box Office Comp')
    end
  end

  context 'for the public order flow (cannot view_backend_classes)' do
    it 'lists only web-visible classes' do
      render_selector(can_view_backend: false)

      expect(rendered).to include('General Admission')
      expect(rendered).not_to include('Box Office Comp')
    end
  end
end
