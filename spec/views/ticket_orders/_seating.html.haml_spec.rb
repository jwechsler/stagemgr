require 'rails_helper'

# Public reserved-seating order page layout. A landscape seat map runs full
# width ABOVE the selected seats and add-ons; any other map sits beside them
# (selected seats first) from medium up. The child partials are stubbed with
# their real landmark ids so the spec checks only the wrapper this partial owns.
# The map sits in a .seating-layout__map wrapper, outlined only for a PNG map.
RSpec.describe 'ticket_orders/_seating', type: :view do
  def render_seating(is_landscape:, is_png: false)
    seat_map = instance_double(SeatMap, landscape?: is_landscape, png_image?: is_png)
    production = instance_double(Production, seat_map: seat_map)
    performance = instance_double(Performance, production: production)
    ticket_order = double('ticket_order', performance: performance)
    order_form = double('order_form', object: double('order', performance_id: nil))

    stub_template 'seat_assignments/_ticket_class_selector.html.haml' => ''
    stub_template 'ticket_orders/_ticket_line_items.html.haml' =>
                    "%h4 Selected Seats\n%span#seatlocations\n#ticket-display"
    stub_template 'seat_assignments/_non_seat_ticket_picker.html.haml' => '#non-seat-ticket-picker'
    stub_template 'admin/ticket_orders/_seatmap.html.haml' => '%figure#seatingmap'

    render partial: 'ticket_orders/seating', locals: { order_form: order_form, ticket_order: ticket_order }
    Capybara.string(rendered)
  end

  def cells(page, layout_class)
    page.all(".seating-layout.#{layout_class} > .cell")
  end

  context 'with a landscape seat map' do
    let(:page) { render_seating(is_landscape: true) }

    it 'marks the layout landscape' do
      expect(page).to have_css('.grid-x.grid-padding-x.seating-layout.seating-layout--landscape')
      expect(page).to have_no_css('.seating-layout--portrait')
    end

    it 'puts the map cell first and the selected seats and add-ons cell second' do
      expect(cells(page, 'seating-layout--landscape').size).to eq(2)
      expect(page).to have_css('.seating-layout--landscape > .cell:first-child #seatingmap')
      expect(page).to have_css('.seating-layout--landscape > .cell:last-child #seatlocations')
      expect(page).to have_css('.seating-layout--landscape > .cell:last-child #ticket-display')
      expect(page).to have_css('.seating-layout--landscape > .cell:last-child #non-seat-ticket-picker')
      expect(page).to have_no_css('.seating-layout--landscape > .cell:first-child #seatlocations')
    end

    it 'gives both cells the full width at every size' do
      expect(cells(page, 'seating-layout--landscape')).to all(match_css('.small-12'))
      expect(page).to have_no_css('.seating-layout > .cell.medium-6')
    end
  end

  context 'with a portrait or square seat map' do
    let(:page) { render_seating(is_landscape: false) }

    it 'marks the layout portrait' do
      expect(page).to have_css('.grid-x.grid-padding-x.seating-layout.seating-layout--portrait')
      expect(page).to have_no_css('.seating-layout--landscape')
    end

    it 'puts the selected seats and add-ons cell first and the map cell second' do
      expect(cells(page, 'seating-layout--portrait').size).to eq(2)
      expect(page).to have_css('.seating-layout--portrait > .cell:first-child #seatlocations')
      expect(page).to have_css('.seating-layout--portrait > .cell:first-child #ticket-display')
      expect(page).to have_css('.seating-layout--portrait > .cell:first-child #non-seat-ticket-picker')
      expect(page).to have_css('.seating-layout--portrait > .cell:last-child #seatingmap')
      expect(page).to have_no_css('.seating-layout--portrait > .cell:first-child #seatingmap')
    end

    it 'splits the cells in half from medium up' do
      expect(cells(page, 'seating-layout--portrait')).to all(match_css('.small-12.medium-6'))
    end
  end

  describe 'map wrapper' do
    it 'wraps the map inside the first cell of a landscape layout' do
      page = render_seating(is_landscape: true)

      expect(page).to have_css('.seating-layout--landscape > .cell:first-child > .seating-layout__map > #seatingmap')
      expect(page).to have_css('.seating-layout__map', count: 1)
    end

    it 'wraps the map inside the last cell of a portrait layout' do
      page = render_seating(is_landscape: false)

      expect(page).to have_css('.seating-layout--portrait > .cell:last-child > .seating-layout__map > #seatingmap')
      expect(page).to have_css('.seating-layout__map', count: 1)
    end

    it 'leaves the selected seats outside the wrapper' do
      page = render_seating(is_landscape: false)

      expect(page).to have_no_css('.seating-layout__map #seatlocations')
      expect(page).to have_no_css('.seating-layout__map #non-seat-ticket-picker')
    end

    it 'outlines a PNG map' do
      page = render_seating(is_landscape: false, is_png: true)

      expect(page).to have_css('.seating-layout__map.seating-layout__map--outlined > #seatingmap')
    end

    it 'does not outline a non-PNG map' do
      page = render_seating(is_landscape: false, is_png: false)

      expect(page).to have_css('.seating-layout__map > #seatingmap')
      expect(page).to have_no_css('.seating-layout__map--outlined')
    end

    it 'does not outline a non-PNG landscape map' do
      page = render_seating(is_landscape: true, is_png: false)

      expect(page).to have_no_css('.seating-layout__map--outlined')
    end

    it 'gives a landscape PNG map both the landscape order and the outline' do
      page = render_seating(is_landscape: true, is_png: true)

      expect(page).to have_css(
        '.seating-layout--landscape > .cell:first-child > .seating-layout__map.seating-layout__map--outlined > #seatingmap'
      )
      expect(page).to have_css('.seating-layout--landscape > .cell:last-child #seatlocations')
    end
  end
end
