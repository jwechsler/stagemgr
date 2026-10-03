require 'rails_helper'

# The orders listing's "Needs review" status filter and Review badge, both
# driven by the review columns alone (no balance is worked out per row).
RSpec.describe Admin::OrdersController, 'needs review', type: :controller do
  let(:box_office_user) { FactoryBot.create(:user, is_box_office_user: true) }
  let!(:flagged) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let!(:resolved) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let!(:plain) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }

  before do
    allow(controller).to receive(:current_user).and_return(box_office_user)
    flagged.flag_for_review!('Stripe refund $20.00 on 10/02 <script>')
    resolved.flag_for_review!('Stripe refund $5.00 on 10/01')
    resolved.resolve_review!(box_office_user, 'ok')
  end

  let(:column_names) { %w[id code name seats status visits total description order_id] }

  def listing(status_filter)
    columns = column_names.each_with_index.to_h do |name, index|
      [index.to_s, { data: name, name: '', searchable: (index < 5).to_s, orderable: 'true',
                     search: { value: index == 4 ? status_filter : '', regex: 'false' } }]
    end
    get :index, format: :json, params: { draw: '1', start: '0', length: '25', columns: columns,
                                         order: { '0' => { column: '0', dir: 'desc' } },
                                         search: { value: '', regex: 'false' } }
    response.parsed_body['data'].each { |row| row['order_id'] = row['order_id'].to_i }
  end

  it 'lists only orders flagged and not yet resolved under "Needs review"' do
    rows = listing(OrdersDatatable::NEEDS_REVIEW)

    expect(rows.pluck('order_id')).to eq([flagged.id])
  end

  it 'badges a flagged order with its reason as an escaped tooltip' do
    rows = listing('').index_by { |row| row['order_id'] }

    badge = Nokogiri::HTML.fragment(rows[flagged.id]['status']).at_css('span.review-flag')
    expect(badge.text).to eq('Review')
    expect(badge['title']).to eq('Stripe refund $20.00 on 10/02 <script>')
    expect(rows[flagged.id]['status']).not_to include('<script>')
    expect(rows[resolved.id]['status']).not_to include('review-flag')
    expect(rows[plain.id]['status']).not_to include('review-flag')
  end

  it 'still filters by an ordinary status' do
    plain.update_columns(status: Order::FULFILLED)

    rows = listing(Order::FULFILLED)

    expect(rows.pluck('order_id')).to eq([plain.id])
  end
end
