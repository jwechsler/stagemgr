require 'rails_helper'

# config/initializers/resque.rb has already run by the time any spec loads, so
# these examples check the state it leaves behind. Every Rails process runs
# that initializer, and its Resque.schedule= flags every entry as changed in
# Redis; a scheduler in dynamic mode then reschedules every job on each boot,
# restarting every `every:` interval so those jobs may never fire.
RSpec.describe 'Resque schedule initializer' do
  it 'leaves dynamic schedule mode off' do
    expect(Resque::Scheduler.dynamic).to be_falsey
  end

  # resque-scheduler defaults `dynamic` from this variable, so exporting it
  # would turn dynamic mode back on behind the initializer's back.
  it 'runs without DYNAMIC_SCHEDULE in the environment' do
    expect(ENV.fetch('DYNAMIC_SCHEDULE', nil)).to be_blank
  end

  it 'loads every job from config/schedule.yml' do
    expected = YAML.load_file(Rails.root.join('config/schedule.yml')).keys

    expect(Resque.schedule.keys).to match_array(expected)
  end
end
