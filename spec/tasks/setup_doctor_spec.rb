require 'rails_helper'
require Rails.root.join('lib/tasks/setup/doctor')

# The individual checks are exercised directly rather than through #run: a full
# run also touches this machine's database and Redis, and the behaviour worth
# pinning down here is the severity each finding is given — that is what decides
# `rake setup:doctor`'s exit status, and therefore whether a deploy proceeds.
RSpec.describe Setup::Doctor do
  subject(:doctor) { described_class.new(out: output) }

  let(:output) { StringIO.new }

  def in_production
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
  end

  describe '.redact' do
    it 'removes the userinfo from a DSN' do
      expect(described_class.redact('redis://appuser:s3cret@redis.example:6379/0'))
        .to eq('redis://***@redis.example:6379/0')
    end

    it 'leaves a DSN without credentials alone' do
      expect(described_class.redact('redis://127.0.0.1:6379/0')).to eq('redis://127.0.0.1:6379/0')
    end

    it 'copes with nil and with plain text' do
      expect(described_class.redact(nil)).to eq('')
      expect(described_class.redact('not a url')).to eq('not a url')
    end
  end

  describe 'required secrets' do
    before do
      allow(RequiredSecrets).to receive(:missing).and_return([:stripe_secret_key])
      allow(RequiredSecrets).to receive(:warn_only_missing).and_return([])
    end

    it 'warns outside production — a developer without a Stripe key is fine' do
      doctor.send(:check_required_secrets)

      expect(output.string).to include('warn')
      expect(doctor).to be_healthy
    end

    it 'fails in production, where a missing key means broken checkout' do
      in_production
      doctor.send(:check_required_secrets)

      expect(output.string).to include('FAIL')
      expect(doctor).not_to be_healthy
    end

    it 'reports success when nothing is missing' do
      allow(RequiredSecrets).to receive(:missing).and_return([])
      doctor.send(:check_required_secrets)

      expect(output.string).to include('all secrets required by this configuration are present')
      expect(doctor).to be_healthy
    end
  end

  describe 'credentials store' do
    before { allow(AppSecrets).to receive(:credentials_file).and_return('config/credentials/production.yml.enc') }

    # The failure that makes every other diagnostic lie: the credentials are
    # there, the key is not, and each secret reads as missing.
    it 'fails when the file is present but undecryptable' do
      allow(AppSecrets).to receive(:credentials_status).and_return(:no_key)
      # No stubbing of anything else: the message must build from Rails.env
      # alone (an earlier version called AppSecrets.env_name without its
      # argument and only a stub kept the spec green).
      doctor.send(:check_credentials_store)

      expect(output.string).to include('FAIL', 'no decryption key', "config/credentials/#{Rails.env}.key",
                                       'RAILS_MASTER_KEY')
      expect(doctor).not_to be_healthy
    end

    it 'is happy when the credentials decrypt' do
      allow(AppSecrets).to receive(:credentials_status).and_return(:ok)

      doctor.send(:check_credentials_store)

      expect(output.string).to include('encrypted credentials readable')
      expect(doctor).to be_healthy
    end

    it 'is happy with no credentials file at all — an ENV-only deployment' do
      allow(AppSecrets).to receive(:credentials_status).and_return(:absent)

      doctor.send(:check_credentials_store)

      expect(output.string).to include('secrets come from the environment')
      expect(doctor).to be_healthy
    end
  end

  describe 'the secrets inventory' do
    it 'does not re-report the credentials status entry as if it were a secret' do
      doctor.send(:check_secrets)

      expect(output.string).not_to include('credentials_status')
    end
  end

  describe 'redis' do
    around do |example|
      original = ENV.fetch('REDIS_URL', nil)
      ENV['REDIS_URL'] = 'redis://appuser:s3cret@redis.example:6379/0'
      example.run
      ENV['REDIS_URL'] = original
    end

    it 'never prints the password, on success or on failure' do
      allow(Resque).to receive(:redis).and_raise(Redis::CannotConnectError,
                                                 'Error connecting to redis://appuser:s3cret@redis.example:6379/0')

      doctor.send(:check_redis)

      expect(output.string).to include('redis://***@redis.example:6379/0')
      expect(output.string).not_to include('s3cret')
      expect(doctor).not_to be_healthy
    end
  end

  describe 'the public layout' do
    it 'fails when server.yml points at a template that does not resolve' do
      allow(doctor).to receive(:server_config).and_return('ext_site_wrapper' => 'no_such_layout')

      doctor.send(:check_site_wrapper_layout)

      expect(output.string).to include('FAIL', 'every public page will 500', 'standalone')
      expect(doctor).not_to be_healthy
    end
  end

  # Every example here stubs MyEmma: a doctor run must never reach the network
  # from the test suite (the check is skipped for real, because the test
  # environment sets no MyEmma credentials, so MyEmma.disabled? is true).
  describe 'the MyEmma groups' do
    before do
      allow(MyEmma).to receive(:disabled?).and_return(false)
      allow(MyEmma).to receive(:read_only?).and_return(false)
      allow(MyEmmaGroups).to receive(:name_for).and_return('Newsletter')
      allow(MyEmmaGroups).to receive(:id_for).and_return(11)
    end

    it 'reports each configured group that resolves' do
      doctor.send(:check_myemma_groups)

      expect(output.string).to include('newsletter_group', 'coupon_group', "'Newsletter' found")
      expect(doctor).to be_healthy
    end

    it 'warns — never fails — for a group name that is not in the account' do
      allow(MyEmmaGroups).to receive(:id_for).and_return(nil)

      doctor.send(:check_myemma_groups)

      expect(output.string).to include('warn', 'does not exist in this Emma account')
      expect(doctor).to be_healthy
    end

    it 'says so when a group has been switched off with a blank name' do
      allow(MyEmmaGroups).to receive(:name_for).and_return(nil)

      doctor.send(:check_myemma_groups)

      expect(output.string).to include('is blank — nobody is added to that group')
      expect(doctor).to be_healthy
    end

    it 'makes no API call when MyEmma is not configured' do
      allow(MyEmma).to receive(:disabled?).and_return(true)
      expect(MyEmmaGroups).not_to receive(:id_for)

      doctor.send(:check_myemma_groups)

      expect(output.string).to include('MyEmma is not configured')
    end

    it 'makes no API call in a read-only environment such as development' do
      allow(MyEmma).to receive(:read_only?).and_return(true)
      expect(MyEmmaGroups).not_to receive(:id_for)

      doctor.send(:check_myemma_groups)

      expect(output.string).to include('read-only')
    end

    it 'warns rather than blowing up when the API is unreachable' do
      allow(MyEmmaGroups).to receive(:id_for).and_raise(SocketError, 'getaddrinfo: nodename nor servname provided')

      doctor.send(:check_myemma_groups)

      expect(output.string).to include('warn', 'MyEmma groups not verified')
      expect(doctor).to be_healthy
    end
  end

  describe 'the site theme' do
    it 'fails when server.yml names a theme directory that is not there' do
      allow(doctor).to receive(:server_config).and_return('site_theme' => 'nowhere')

      doctor.send(:check_site_theme)

      expect(output.string).to include('FAIL', 'setup:site[nowhere]')
      expect(doctor).not_to be_healthy
    end

    it 'is happy with no theme — the generic views are a valid configuration' do
      allow(doctor).to receive(:server_config).and_return({})

      doctor.send(:check_site_theme)

      expect(doctor).to be_healthy
    end
  end
end
