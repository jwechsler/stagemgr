require 'rails_helper'

# Seat-selection ticket class modal, shared by the public order flow and the
# admin (box office) order flow. The gate is the show_backend_classes RENDER
# CONTEXT local, not the user's ability: the admin page passes true so staff
# can sell classes hidden from the public purchase page (web_visible == false);
# the public flow omits it and must only ever list web-visible classes, no
# matter who is signed in. PerformancesController#ticket_classes applies the
# same rule via the include_backend param.
RSpec.describe 'seat_assignments/_ticket_class_selector', type: :view do
  def ticket_class(class_name:, web_visible:, holds_seats: true)
    tc = TicketClass.new(
      class_code: class_name.upcase.delete(' '), class_name: class_name,
      ticket_price: 25, ticket_type: 'Fixed', web_visible: web_visible,
      software_managed: false, hide_pricing: false, zone_id: 'A',
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

  # show_backend_classes: :omitted exercises the default (public) render path.
  def render_selector(show_backend_classes: :omitted)
    public_class = ticket_class(class_name: 'General Admission', web_visible: true)
    backend_class = ticket_class(class_name: 'Box Office Comp', web_visible: false)
    non_seat_class = ticket_class(class_name: 'Hearing Assist', web_visible: true, holds_seats: false)

    performance = instance_double(Performance,
                                  ticket_class_allocations: [allocation(public_class), allocation(backend_class),
                                                             allocation(non_seat_class)])
    order = double('order', performance: performance, performance_id: 1, uuid: 'test-uuid')
    order_form = double('order_form', object: order)

    # The ability must be irrelevant to this partial: stub it true everywhere
    # to prove a signed-in staff member browsing the public flow still gets
    # the filtered list (the July 2026 regression).
    allow(view).to receive(:can?).with(:view_backend_classes, TicketClassAllocation)
                                 .and_return(true)
    stub_template 'seat_assignments/_seating_config.html.haml' => ''

    locals = { order_form: order_form }
    locals[:show_backend_classes] = show_backend_classes unless show_backend_classes == :omitted
    render partial: 'seat_assignments/ticket_class_selector', locals: locals
  end

  context 'admin box-office render (show_backend_classes: true)' do
    it 'lists classes that are hidden from the public purchase page' do
      render_selector(show_backend_classes: true)

      expect(rendered).to include('General Admission')
      expect(rendered).to include('Box Office Comp')
    end
  end

  context 'public order flow (local omitted)' do
    it 'lists only web-visible classes even when the viewer holds view_backend_classes' do
      render_selector

      expect(rendered).to include('General Admission')
      expect(rendered).not_to include('Box Office Comp')
    end
  end

  context 'public order flow (show_backend_classes: false)' do
    it 'lists only web-visible classes' do
      render_selector(show_backend_classes: false)

      expect(rendered).to include('General Admission')
      expect(rendered).not_to include('Box Office Comp')
    end
  end

  context 'non-seat-holding classes (holds_seats == false)' do
    it 'never lists them — a seat click can only assign seat-holding classes' do
      render_selector(show_backend_classes: true)

      expect(rendered).not_to include('Hearing Assist')
    end
  end
end
