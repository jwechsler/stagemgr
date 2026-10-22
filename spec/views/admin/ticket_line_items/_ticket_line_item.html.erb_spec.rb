require 'rails_helper'

# Face Value cell on the admin order page (confirm and detail tables). It must
# agree with TicketLineItem#total, so a pass redemption that kept a capped
# price_override on a Fixed class shows the capped amount, not the class price.
RSpec.describe 'admin/ticket_line_items/_ticket_line_item', type: :view do
  let(:ticket_class) do
    TicketClass.new(class_code: 'FLEX20', class_name: 'Flex Pass', ticket_price: BigDecimal('22.50'),
                    ticket_type: 'Fixed')
  end

  def face_value_for(line_item)
    render partial: 'admin/ticket_line_items/ticket_line_item', locals: { ticket_line_item: line_item }
    Nokogiri::HTML.fragment(rendered).css('td').last.text.strip
  end

  it 'shows the overridden total for a Fixed class with a price_override' do
    line_item = TicketLineItem.new(ticket_class: ticket_class, ticket_count: 2, price_override: BigDecimal('20'))

    expect(face_value_for(line_item)).to eq('$40.00')
  end

  it 'shows the class price total when there is no price_override' do
    line_item = TicketLineItem.new(ticket_class: ticket_class, ticket_count: 2)

    expect(face_value_for(line_item)).to eq('$45.00')
  end
end
