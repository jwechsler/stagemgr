require 'rails_helper'

RSpec.describe FlexPassOrdersDatatable do
  let(:admin) { FactoryBot.create(:admin_user) }

  # A DataTables request as the flex pass order page's Order History sends it.
  let(:params) do
    columns = %w[order created description amount status].each_with_index.to_h do |column, i|
      [i.to_s, { data: column, name: '', searchable: 'true', orderable: 'true',
                 search: { value: '', regex: 'false' } }]
    end
    ActionController::Parameters.new(draw: '1', start: '0', length: '10', columns: columns,
                                     order: { '0' => { column: '0', dir: 'desc' } },
                                     search: { value: '', regex: 'false' })
  end

  it 'returns an empty history, not an error, when the order has no flex pass' do
    json = described_class.new(params, current_user: admin, flex_pass: nil).as_json

    expect(json[:data]).to eq([])
    expect(json[:recordsTotal]).to eq(0)
  end
end
