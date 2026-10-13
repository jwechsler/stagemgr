require 'rails_helper'

RSpec.describe PerformanceDatatable do
  let(:production) { FactoryBot.create(:production) }

  # A DataTables request as the admin production page sends it: no :order key,
  # because the performance listing is configured with `ordering: false`.
  let(:params) do
    ActionController::Parameters.new(
      draw: '1',
      start: '0',
      length: '25',
      columns: {
        '0' => { data: 'code', name: '', searchable: 'true', orderable: 'false',
                 search: { value: '', regex: 'false' } },
        '1' => { data: 'date', name: '', searchable: 'true', orderable: 'false',
                 search: { value: '', regex: 'false' } },
        '2' => { data: 'time', name: '', searchable: 'false', orderable: 'false',
                 search: { value: '', regex: 'false' } },
        '3' => { data: 'status', name: '', searchable: 'true', orderable: 'false',
                 search: { value: '', regex: 'false' } },
        '4' => { data: 'pace', name: '', searchable: 'false', orderable: 'false',
                 search: { value: '', regex: 'false' } },
        '5' => { data: 'actions', name: '', searchable: 'false', orderable: 'false',
                 search: { value: '', regex: 'false' } }
      },
      search: { value: '', regex: 'false' }
    )
  end

  subject(:datatable) { described_class.new(params, production: production) }

  describe 'record ordering' do
    it 'orders performances by date and time rather than by id' do
      # Created out of chronological order so id order and date order differ.
      later_day     = create_performance(Date.current + 2.days, '19:30')
      earlier_day   = create_performance(Date.current + 1.day, '19:30')
      same_day_late = create_performance(Date.current + 1.day, '14:00')

      expect(datatable.send(:records).to_a).to eq([same_day_late, earlier_day, later_day])
    end

    it 'orders performances on the same date by time' do
      evening = create_performance(Date.current + 1.day, '19:30')
      matinee = create_performance(Date.current + 1.day, '14:00')

      expect(datatable.send(:records).to_a).to eq([matinee, evening])
    end
  end

  describe 'pace column' do
    let(:admin) { FactoryBot.create(:admin_user) }
    let(:view) do
      controller = ApplicationController.new
      controller.request = ActionDispatch::TestRequest.create
      controller.view_context.tap { |v| allow(v).to receive(:current_user).and_return(admin) }
    end

    # The decorators' action links render through Draper's view context.
    before { Draper::ViewContext.current = view }
    after { Draper::ViewContext.clear! }

    def json_rows
      described_class.new(params, production: production, view_context: view).as_json[:data]
    end

    def too_early_reading(performance)
      AdvanceSalesPace::Reading.new(performance_id: performance.id, days_out: 30, sold: 2, typical_share: 0.05,
                                    projected_final: nil, capacity: 100, projected_pct_of_capacity: nil,
                                    source: :theater)
    end

    it 'renders a pace cell for upcoming performances and a dash for past ones' do
      past     = create_performance(Date.current - 3.days, '19:30')
      upcoming = create_performance(Date.current + 30.days, '19:30')
      allow(AdvanceSalesPace).to receive(:for_production).with(production)
                                                         .and_return(upcoming.id => too_early_reading(upcoming))

      rows = json_rows.index_by { |row| row[:DT_RowId] } # as_json stringifies the values

      expect(rows[upcoming.id.to_s][:pace]).to include('Too early')
      expect(rows[past.id.to_s][:pace]).to eq(Admin::AdvanceSalesHelper::EMPTY_CELL)
    end

    it 'renders a titled dash when the production records its sales externally' do
      production.update_column(:sales_recorded_externally, true)
      performance = create_performance(Date.current + 30.days, '19:30')

      row = json_rows.find { |r| r[:DT_RowId] == performance.id.to_s }

      expect(row[:pace]).to eq('<span title="Sales recorded externally">—</span>')
    end

    it 'computes the pace readings once per request' do
      create_performance(Date.current + 1.day, '19:30')
      create_performance(Date.current + 2.days, '19:30')
      create_performance(Date.current + 3.days, '19:30')
      expect(AdvanceSalesPace).to receive(:for_production).once.and_return({})

      expect(json_rows.size).to eq(3)
    end
  end

  # performance_time is a bare `time` column and default_timezone is :local, so
  # ActiveRecord stores the *system* wall-clock time. Build the value in the
  # system zone (Time.local) rather than Time.zone, or the stored hour shifts by
  # the offset between the two: on a UTC host 19:30 Central lands as 00:30 and
  # sorts before 14:00 Central (19:00).
  def create_performance(date, time)
    hour, minute = time.split(':').map(&:to_i)
    FactoryBot.create(:performance,
                      production: production,
                      performance_date: date,
                      performance_time: Time.local(date.year, date.month, date.day, hour, minute))
  end
end
