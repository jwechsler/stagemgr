require 'rails_helper'

# Request specs hit the app without the /tickets sub-URI (Passenger strips it
# in deployment), so the throttled page here is '/'.
RSpec.describe 'Rack::Attack throttling', type: :request do
  let(:test_req_limit) { 3 }

  around do |example|
    original_enabled = Rack::Attack.enabled
    original_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.cache.store.clear
    Rack::Attack.cache.store = original_store
    Rack::Attack.enabled = original_enabled
  end

  # Swap in a low-limit copy of the configured 'req/ip' throttle, reusing its
  # discriminator block, and put the original object back afterwards.
  before do
    @original_req_ip = Rack::Attack.throttles['req/ip']
    Rack::Attack.throttle('req/ip', limit: test_req_limit, period: @original_req_ip.period, &@original_req_ip.block)
  end

  after { Rack::Attack.throttles['req/ip'] = @original_req_ip }

  def log_in(user)
    post '/user_session', params: { user_session: { email: user.email, password: 'password' } }
    expect(response).to have_http_status(:redirect)
    # Start the count after the login POST so only the GETs below are counted.
    Rack::Attack.cache.store.clear
  end

  def limit_plus_one_gets
    Array.new(test_req_limit + 1) do
      get '/'
      response
    end
  end

  it 'throttles an anonymous visitor on the fourth request with a Retry-After header' do
    responses = limit_plus_one_gets

    expect(responses.first(test_req_limit).map(&:status)).not_to include(429)
    expect(responses.last).to have_http_status(429)
    expect(responses.last.headers['Retry-After']).to be_present
  end

  it 'never throttles a signed-in box office user' do
    log_in(FactoryBot.create(:user, is_box_office_user: true))

    statuses = limit_plus_one_gets.map(&:status)

    expect(statuses).to all(satisfy { |s| [200, 302].include?(s) })
  end

  it 'throttles a signed-in theater-company user on the fourth request' do
    log_in(FactoryBot.create(:user, is_administrator: false, is_box_office_user: false))

    responses = limit_plus_one_gets

    expect(responses.first(test_req_limit).map(&:status)).not_to include(429)
    expect(responses.last).to have_http_status(429)
  end
end
