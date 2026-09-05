require 'rails_helper'

RSpec.describe AppSecrets do
  # Everything is driven through an injected Resolver: no real ENV, no decrypted
  # credentials file, so these examples say the same thing on a laptop with a
  # populated .env and on CI with none.
  let(:credentials) { { stripe: { secret_key: 'sk_from_credentials' } } }
  let(:server_config) { {} }
  let(:env) { {} }

  def resolver(env_hash = env, credentials_hash = credentials, server_hash = server_config)
    described_class::Resolver.new(env: env_hash, credentials: credentials_hash, server_config: server_hash)
  end

  describe '#[]' do
    it 'prefers a non-blank environment variable over the credential' do
      value = resolver({ 'STRIPE_SECRET_KEY' => 'sk_from_env' })[:stripe_secret_key]

      expect(value).to eq('sk_from_env')
    end

    it 'falls through to the credential when the environment variable is empty' do
      value = resolver({ 'STRIPE_SECRET_KEY' => '' })[:stripe_secret_key]

      expect(value).to eq('sk_from_credentials')
    end

    # The Aug 2026 Postmark outage: `POSTMARK_API_TOKEN=` with a stray space
    # after it is truthy in Ruby, so it shadowed a working credential and every
    # send 401'd. Whitespace is not a secret.
    it 'treats a whitespace-only environment variable as absent' do
      value = resolver({ 'STRIPE_SECRET_KEY' => "  \t " })[:stripe_secret_key]

      expect(value).to eq('sk_from_credentials')
    end

    it 'strips surrounding whitespace from the value it returns' do
      value = resolver({ 'STRIPE_SECRET_KEY' => "  sk_padded\n" })[:stripe_secret_key]

      expect(value).to eq('sk_padded')
    end

    it 'returns nil when no source supplies the secret' do
      expect(resolver({}, {})[:postmark_api_token]).to be_nil
    end

    it 'reads a top-level credential as well as a nested one' do
      value = resolver({}, { postmark_api_token: 'pm_token' })[:postmark_api_token]

      expect(value).to eq('pm_token')
    end

    it 'coerces a non-string credential, such as a numeric MyEmma account id' do
      value = resolver({}, { my_emma: { account_id: 99_999_999 } })[:my_emma_account_id]

      expect(value).to eq('99999999')
    end

    it 'survives a credential whose shape has drifted to a scalar' do
      expect(resolver({}, { stripe: 'sk_oops' })[:stripe_secret_key]).to be_nil
    end

    it 'raises on an unregistered name rather than quietly returning nil' do
      expect { resolver[:not_a_secret] }.to raise_error(described_class::UnknownSecret, /not_a_secret/)
    end
  end

  describe 'the deprecated server.yml fallback' do
    let(:server_config) { { 'resque_admin_password' => 'from_server_yml' } }

    before do
      allow(Kernel).to receive(:warn)
      # Theater Wit's own server.yml carries the key in its test: block, so the
      # stderr half of the warning is suppressed under RAILS_ENV=test to keep
      # every rspec and cucumber boot quiet. These examples are about the
      # warning itself, so they run as though booted in development.
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
    end

    it 'still resolves the Resque password left in server.yml' do
      expect(resolver[:resque_admin_password]).to eq('from_server_yml')
    end

    it 'warns once per key, naming both replacements' do
      subject = resolver
      3.times { subject[:resque_admin_password] }

      expect(Kernel).to have_received(:warn)
        .with(/DEPRECATED.*RESQUE_ADMIN_PASSWORD.*resque_admin_password/m).once
    end

    it 'does not warn when ENV or the credentials already supply the value' do
      value = resolver({ 'RESQUE_ADMIN_PASSWORD' => 'from_env' })[:resque_admin_password]

      expect(value).to eq('from_env')
      expect(Kernel).not_to have_received(:warn)
    end

    it 'reads server.yml with indifferent access' do
      subject = described_class::Resolver.new(env: {}, credentials: {},
                                              server_config: { resque_admin_password: 'symbol_keyed' })

      expect(subject[:resque_admin_password]).to eq('symbol_keyed')
    end

    it 'is offered for no other secret' do
      subject = resolver({}, {}, { 'stripe_secret_key' => 'nope', 'postmark_api_token' => 'nope' })

      expect(subject[:stripe_secret_key]).to be_nil
      expect(subject[:postmark_api_token]).to be_nil
    end

    it 'keeps stderr clean in the test environment but still logs the warning' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
      allow(Rails.logger).to receive(:warn)

      resolver[:resque_admin_password]

      expect(Kernel).not_to have_received(:warn)
      expect(Rails.logger).to have_received(:warn).with(/DEPRECATED/)
    end

    it 'is resolved lazily, so config.x.server_config can be assigned after boot' do
      config = nil
      subject = described_class::Resolver.new(env: {}, credentials: {}, server_config: -> { config })
      config = { 'resque_admin_password' => 'late' }

      expect(subject[:resque_admin_password]).to eq('late')
    end
  end

  describe '#source' do
    it 'names the layer each secret came from' do
      subject = described_class::Resolver.new(
        env: { 'POSTMARK_API_TOKEN' => 'pm' },
        credentials: credentials,
        server_config: { 'resque_admin_password' => 'rq' }
      )
      allow(Kernel).to receive(:warn)

      expect(subject.source(:postmark_api_token)).to eq(:env)
      expect(subject.source(:stripe_secret_key)).to eq(:credentials)
      expect(subject.source(:resque_admin_password)).to eq(:server_yml)
      expect(subject.source(:aws_access_key_id)).to eq(:none)
    end
  end

  describe '#report' do
    it 'covers every registered secret, plus the credentials status, with no values' do
      report = resolver({ 'STRIPE_SECRET_KEY' => 'sk_from_env' }).report

      expect(report.keys).to match_array(described_class::REGISTRY.keys + [:credentials_status])
      expect(report[:stripe_secret_key])
        .to eq(source: :env, blank_env: false, env: 'STRIPE_SECRET_KEY', credentials: 'stripe.secret_key')
      expect(report.to_s).not_to include('sk_from_env')
    end

    it 'gives the credentials-status entry the same shape as the secrets, so callers can iterate' do
      report = resolver.report

      expect(report[:credentials_status].keys).to eq(report[:stripe_secret_key].keys)
      expect(report[:credentials_status][:source]).to eq(:unavailable)
    end

    it 'flags an environment variable that is set but blank' do
      report = resolver({ 'POSTMARK_API_TOKEN' => '   ' }).report

      expect(report[:postmark_api_token]).to include(blank_env: true, source: :none)
      expect(report[:stripe_secret_key]).to include(blank_env: false)
    end
  end

  # The trap: EncryptedConfiguration#read rescues MissingContentError and returns
  # {}, so an .enc with no key looks exactly like an .enc with nothing in it, and
  # every credential quietly reads as nil.
  describe '#credentials_status' do
    def store(exists:, key:)
      instance_double(ActiveSupport::EncryptedConfiguration,
                      content_path: instance_double(Pathname, exist?: exists), key: key)
    end

    it 'is :ok when the file is present and a key resolves' do
      subject = described_class::Resolver.new(env: {}, credentials: store(exists: true, key: 'k'))

      expect(subject.credentials_status).to eq(:ok)
    end

    it 'is :no_key when the file is present but no key was found' do
      subject = described_class::Resolver.new(env: {}, credentials: store(exists: true, key: nil))

      expect(subject.credentials_status).to eq(:no_key)
    end

    it 'is :no_key when reading the key raises, as it does under require_master_key' do
      raising = instance_double(ActiveSupport::EncryptedConfiguration,
                                content_path: instance_double(Pathname, exist?: true))
      allow(raising).to receive(:key).and_raise(ActiveSupport::EncryptedFile::MissingKeyError)
      subject = described_class::Resolver.new(env: {}, credentials: raising)

      expect(subject.credentials_status).to eq(:no_key)
    end

    it 'is :absent when there is no credentials file at all' do
      subject = described_class::Resolver.new(env: {}, credentials: store(exists: false, key: nil))

      expect(subject.credentials_status).to eq(:absent)
    end

    it 'is :unavailable when credentials are not an encrypted store' do
      expect(resolver({}, {}).credentials_status).to eq(:unavailable)
    end

    it 'reports the real application credentials as readable' do
      expect(described_class.credentials_status).to eq(:ok)
      expect(described_class.credentials_file).to eq('config/credentials/test.yml.enc')
    end
  end

  describe '#fetch!' do
    it 'returns the value when one is configured' do
      expect(resolver.fetch!(:stripe_secret_key)).to eq('sk_from_credentials')
    end

    it 'names both the environment variable and the credentials path when absent' do
      expect { resolver({}, {}).fetch!(:my_emma_account_id) }
        .to raise_error(described_class::MissingSecret, /MY_EMMA_ACCOUNT_ID.*my_emma\.account_id/m)
    end
  end

  describe 'the application-wide resolver' do
    after { described_class.reset! }

    it 'reports a source for every registered secret without leaking values' do
      report = described_class.report.except(:credentials_status)

      expect(report.keys).to match_array(described_class::REGISTRY.keys)
      expect(report.values.pluck(:source).uniq).to all(be_in(%i[env credentials server_yml none]))
      expect(report.values.map(&:keys).uniq).to eq([%i[source blank_env env credentials]])
    end

    it 'exposes the naming helpers RequiredSecrets and setup:doctor render' do
      expect(described_class.env_name(:postmark_api_token)).to eq('POSTMARK_API_TOKEN')
      expect(described_class.credentials_path(:stripe_signing_secret)).to eq('stripe.signing_secret')
      expect(described_class.missing_message(:stripe_signing_secret))
        .to match(/STRIPE_SIGNING_SECRET.*stripe\.signing_secret/m)
    end

    it 'delegates to the memoized resolver until reset' do
      first = described_class.default_resolver

      expect(described_class.default_resolver).to be(first)
      described_class.reset!
      expect(described_class.default_resolver).not_to be(first)
    end
  end
end
