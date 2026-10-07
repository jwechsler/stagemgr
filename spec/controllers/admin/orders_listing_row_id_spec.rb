require 'rails_helper'

# DataTables reads each row's id from DT_RowId (exact case). The orders
# listing's Select extension needs it to keep rows selected across
# server-side redraws (sorting, paging, searching).
RSpec.describe Admin::OrdersController, 'listing row ids', type: :controller do
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let!(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }

  before { allow(controller).to receive(:current_user).and_return(box_office_user) }

  it 'identifies each row by DT_RowId' do
    columns = %w[id code name seats status visits total description order_id].each_with_index.to_h do |name, index|
      [index.to_s, { data: name, name: '', searchable: (index < 5).to_s, orderable: 'true',
                     search: { value: '', regex: 'false' } }]
    end

    get :index, format: :json, params: { draw: '1', start: '0', length: '25', columns: columns,
                                         order: { '0' => { column: '0', dir: 'desc' } },
                                         search: { value: '', regex: 'false' } }

    expect(response.parsed_body['data'].pluck('DT_RowId').map(&:to_s)).to include(order.id.to_s)
  end
end
