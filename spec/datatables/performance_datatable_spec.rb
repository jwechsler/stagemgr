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
        '4' => { data: 'actions', name: '', searchable: 'false', orderable: 'false',
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

  def create_performance(date, time)
    FactoryBot.create(:performance,
                      production: production,
                      performance_date: date,
                      performance_time: Time.zone.parse("#{date} #{time}"))
  end
end
