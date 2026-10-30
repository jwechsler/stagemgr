require 'rails_helper'

# Production: 250k orders, each COUNT(DISTINCT orders.id) over the eager-load joins examines ~1M rows in 3.4-4.3 s, twice per draw.
# The datatable's total and filtered counts must not eager-load: no seats join ever, other joins only when a filter needs them.
RSpec.describe OrdersDatatable do
  let(:admin) { FactoryBot.create(:admin_user) }
  let(:column_names) { %w[id code name seats status visits total description order_id] }

  # Two seats on one order so a naive join would multiply its rows.
  let!(:seated) do
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating,
                      address: FactoryBot.create(:address, last_name: 'Quillfeather', full_name: 'Ada Quillfeather'))
  end
  let!(:general) { FactoryBot.create(:ticket_order, :for_a_single_ticket) }
  # No address and no performance, so an INNER join would drop it.
  let!(:bare) do
    FactoryBot.create(:donation_order).tap { |order| order.update_columns(address_id: nil) }
  end

  def params(searches = {}, order_column = '0')
    columns = column_names.each_with_index.to_h do |name, index|
      [index.to_s, { data: name, name: '', searchable: (index < 5).to_s, orderable: 'true',
                     search: { value: searches.fetch(name, ''), regex: 'false' } }]
    end
    ActionController::Parameters.new(draw: '1', start: '0', length: '25', columns: columns,
                                     order: { '0' => { column: order_column, dir: 'desc' } },
                                     search: { value: '', regex: 'false' })
  end

  def draw(searches = {}, order_column = '0')
    datatable = described_class.new(params(searches, order_column), current_user: admin)
    statements = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if %w[SCHEMA CACHE].include?(payload[:name])

      statements << payload[:sql]
    end
    json = ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { datatable.as_json }
    [json, statements.grep(/SELECT COUNT/i)]
  end

  it 'has the fixtures the examples rely on' do
    expect(seated.seats.count).to be >= 2
    expect(bare.reload).to have_attributes(address_id: nil, performance_id: nil)
  end

  it 'counts every order once with no search term' do
    json, = draw

    expect(json[:recordsTotal]).to eq(3)
    expect(json[:recordsFiltered]).to eq(3)
    expect(json[:data].size).to eq(3)
    expect(json[:data].pluck(:order_id)).to match_array([seated.id, general.id, bare.id].map(&:to_s))
  end

  it 'counts an unfiltered draw on orders alone' do
    json, counts = draw

    expect(json[:recordsTotal]).to eq(3)
    expect(counts).not_to be_empty
    counts.each do |sql|
      expect(sql).not_to match(/seat_assignments|\bseats\b|addresses|performances|productions|subquery_for_count/),
                         "count statement joins more than orders:\n#{sql}"
    end
  end

  it 'counts a name-filtered draw without the seats join' do
    json, counts = draw('name' => 'Quillfeather')

    expect(json[:recordsTotal]).to eq(3)
    expect(json[:recordsFiltered]).to eq(1)
    expect(json[:data].pluck(:order_id)).to eq([seated.id.to_s])
    expect(counts).not_to be_empty
    counts.each do |sql|
      expect(sql).not_to match(/seat_assignments|\bseats\b/), "count statement joins seats:\n#{sql}"
    end
  end

  it 'counts a code-filtered draw without the seats join' do
    code = seated.performance.performance_code
    expect(general.performance.performance_code).not_to include(code)

    json, counts = draw('code' => code.downcase)

    expect(json[:recordsTotal]).to eq(3)
    expect(json[:recordsFiltered]).to eq(1)
    expect(json[:data].pluck(:order_id)).to eq([seated.id.to_s])
    expect(counts).not_to be_empty
    counts.each do |sql|
      expect(sql).not_to match(/seat_assignments|\bseats\b/), "count statement joins seats:\n#{sql}"
    end
  end

  it 'filters by seat location and lists every seat on the matching order' do
    locations = seated.seats.map { |assignment| assignment.seat.location }
    expect(locations.uniq.size).to be >= 2

    json, = draw('seats' => locations.first.downcase)

    expect(json[:recordsTotal]).to eq(3)
    expect(json[:recordsFiltered]).to eq(1)
    expect(json[:data].pluck(:order_id)).to eq([seated.id.to_s])
    expect(json[:data].first[:seats]).to eq(ERB::Util.html_escape(locations.sort.join(', ')))
  end

  it 'still sorts by the seats column' do
    json, = draw({}, '3')

    expect(json[:recordsFiltered]).to eq(3)
    expect(json[:data].pluck(:order_id)).to match_array([seated.id, general.id, bare.id].map(&:to_s))
  end
end
