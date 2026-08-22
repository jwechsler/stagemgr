require 'rails_helper'

RSpec.describe ExceptionSecretRedactor do
  describe '.session' do
    it 'masks the Authlogic persistence token' do
      result = described_class.session('user_credentials' => 'secret-persistence-token')

      expect(result['user_credentials']).to eq(described_class::FILTERED)
    end

    it 'masks the CSRF token' do
      result = described_class.session('_csrf_token' => 'secret-csrf-token')

      expect(result['_csrf_token']).to eq(described_class::FILTERED)
    end

    # Matched exactly, not by substring: the user id is diagnostically useful and
    # is not a secret. This is what keeps the User section's key field working.
    it 'keeps the session user id' do
      result = described_class.session('user_credentials' => 'token', 'user_credentials_id' => '28')

      expect(result['user_credentials_id']).to eq('28')
    end

    it 'passes other session entries through untouched' do
      result = described_class.session('session_id' => 'abc123', 'return_to' => '/admin/productions')

      expect(result).to include('session_id' => 'abc123', 'return_to' => '/admin/productions')
    end

    it 'handles a session that is not a hash' do
      expect(described_class.session(nil)).to eq({})
    end

    it 'reports rather than raises when the session cannot be read' do
      session = instance_double(ActionDispatch::Request::Session)
      allow(session).to receive(:respond_to?).with(:to_hash).and_return(true)
      allow(session).to receive(:to_hash).and_raise(TypeError, 'nope')

      expect(described_class.session(session)).to eq('session' => 'could not be read: TypeError: nope')
    end

    it 'tracks the session key ExceptionUserContext reads' do
      expect(described_class::SECRET_SESSION_KEYS).to include(ExceptionUserContext::SESSION_TOKEN_KEY)
    end
  end

  describe '.env' do
    it 'scrubs the session token out of a raw Cookie header' do
      env = { 'HTTP_COOKIE' => '_passenger_route=105; user_credentials=abc123%3A%3A28; __ar_v4=xyz' }

      result = described_class.env(env)

      expect(result['HTTP_COOKIE']).to eq("_passenger_route=105; user_credentials=#{described_class::FILTERED}; __ar_v4=xyz")
    end

    it 'leaves the surrounding cookies intact' do
      env = { 'rack.request.cookie_string' => 'user_credentials=abc123; keep=me' }

      expect(described_class.env(env)['rack.request.cookie_string']).to include('keep=me')
    end

    it 'leaves values with no session cookie alone' do
      env = { 'HTTP_HOST' => 'theaterwit.org', 'REQUEST_METHOD' => 'GET' }

      expect(described_class.env(env)).to eq(env)
    end

    it 'passes non-string values through' do
      env = { 'rack.session' => { 'user_credentials_id' => 28 }, 'rack.version' => [1, 3] }

      expect(described_class.env(env)).to eq(env)
    end

    it 'returns the input rather than raising if scrubbing fails' do
      env = { 'HTTP_COOKIE' => 'user_credentials=abc' }
      allow(described_class).to receive(:scrub).and_raise('kaboom')

      expect(described_class.env(env)).to eq(env)
    end
  end

  # The other half of the defence lives in config.filter_parameters, which masks
  # hash entries keyed 'user_credentials' everywhere -- including the log.
  describe 'filter_parameters integration' do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    it 'masks a user_credentials hash entry' do
      expect(filter.filter('user_credentials' => 'tok')['user_credentials']).to eq('[FILTERED]')
    end

    it 'does not mask the user id alongside it' do
      expect(filter.filter('user_credentials_id' => 28)['user_credentials_id']).to eq(28)
    end
  end
end
