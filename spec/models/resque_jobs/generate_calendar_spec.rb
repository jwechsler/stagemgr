require 'rails_helper'

# The subscribable .ics of everything on sale. Its name and timezone used to be
# Theater Wit's, hardcoded; they now come from the house and the application's
# own time zone.
RSpec.describe GenerateCalendar do
  let(:cache_dir) { Dir.mktmpdir }
  # Created before anything else so it wins Theater.default_theater, which picks
  # the lowest-id Default row -- the production factory makes Default rows too.
  let!(:house) { FactoryBot.create(:theater, name: 'Wilma Theater') }

  before do
    allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
    allow(Rails.configuration.x.server_config).to receive(:[]).with('static_cache_dir').and_return(cache_dir)
  end

  after { FileUtils.remove_entry(cache_dir) }

  def generate
    GenerateCalendar.perform('performances.ics')
    File.read(File.join(cache_dir, 'performances.ics'))
  end

  # A visible performance of an active production, dated far enough ahead that it
  # is both inside the calendar's window and still on sale.
  def create_performance(name:, show_description:, at: Time.zone.local(2099, 6, 15, 19, 30))
    production = FactoryBot.create(:production, name: name, show_description: show_description, theater: house,
                                                running_time: 90)
    FactoryBot.create(:performance, production: production, performance_date: at.to_date,
                                    performance_time: at)
  end

  it 'names the calendar after the house and stamps the application time zone' do
    ics = generate

    expect(ics).to include("X-WR-CALNAME:#{house.name} Performance Calendar")
    expect(ics).to include("X-WR-TIMEZONE:VALUE=TEXT:#{Time.zone.tzinfo.identifier}")
  end

  context 'with performances to export' do
    # One described, one not: a production is not required to have a blurb, and a
    # missing one must not take the whole feed down with it.
    let!(:described) { create_performance(name: 'Hamlet', show_description: 'A prince, undone.') }
    let!(:undescribed) do
      create_performance(name: 'Waiting for Godot', show_description: nil,
                         at: Time.zone.local(2099, 6, 16, 20, 0))
    end

    it 'exports every performance' do
      ics = generate

      expect(ics.scan('BEGIN:VEVENT').size).to eq(2)
      expect(ics).to include('SUMMARY:Hamlet')
      expect(ics).to include('SUMMARY:Waiting for Godot')
    end

    it 'writes each start and end as an unambiguous UTC instant' do
      ics = generate

      # ri_cal cannot emit a VTIMEZONE against TZInfo 2, so times go out in UTC;
      # clients render them in the subscriber's own zone.
      expect(ics).to include("DTSTART;VALUE=DATE-TIME:#{described.to_time_with_zone.utc.strftime('%Y%m%dT%H%M%SZ')}")
      expect(ics).to include(
        "DTEND;VALUE=DATE-TIME:#{(described.to_time_with_zone + 90.minutes).utc.strftime('%Y%m%dT%H%M%SZ')}"
      )
    end

    it 'describes the show and points at its order page' do
      ics = generate

      # ri_cal escapes commas and folds long lines, so match on comma-free runs.
      expect(ics).to include('A prince')
      expect(ics).to include('For tickets')
      expect(ics).to include(order_path(described))
    end

    it 'still links a show that has no description' do
      ics = generate

      expect(ics).to include(order_path(undescribed))
    end

    it 'omits the end time when the production has no running time' do
      undescribed.production.update_column(:running_time, nil)

      expect(generate.scan('DTEND').size).to eq(1)
    end

    it 'says nothing about Theater Wit' do
      expect(generate).not_to match(/theater ?wit/i)
    end

    def order_path(perf)
      Rails.application.routes.url_helpers.new_production_performance_order_path(
        production_id: perf.production_id, performance_id: perf.id
      )
    end
  end
end
