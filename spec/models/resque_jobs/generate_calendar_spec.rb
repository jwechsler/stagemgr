require 'rails_helper'

# The subscribable .ics of everything on sale. Its name and timezone used to be
# Theater Wit's, hardcoded; they now come from the house and the application's
# own time zone.
RSpec.describe GenerateCalendar do
  let(:cache_dir) { Dir.mktmpdir }

  before do
    allow(Rails.configuration.x.server_config).to receive(:[]).and_call_original
    allow(Rails.configuration.x.server_config).to receive(:[]).with('static_cache_dir').and_return(cache_dir)
  end

  after { FileUtils.remove_entry(cache_dir) }

  def generate
    GenerateCalendar.perform('performances.ics')
    File.read(File.join(cache_dir, 'performances.ics'))
  end

  it 'names the calendar after the house and stamps the application time zone' do
    house = FactoryBot.create(:theater, name: 'Wilma Theater')

    ics = generate

    expect(ics).to include("X-WR-CALNAME:#{house.name} Performance Calendar")
    expect(ics).to include("X-WR-TIMEZONE:VALUE=TEXT:#{Time.zone.tzinfo.identifier}")
  end

  # NOTE: there is no example here covering the event list, because RiCal cannot
  # serialize a zoned dtstart against the TZInfo this app now runs on
  # (`undefined method 'utc_start' for TZInfo::TransitionsTimezonePeriod`) --
  # a pre-existing breakage in the ri_cal fork, unrelated to the house facts.
end
