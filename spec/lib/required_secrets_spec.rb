require 'rails_helper'

RSpec.describe RequiredSecrets do
  # The production gate is exercised here rather than by booting production:
  # everything it reads (server.yml shape, AppSecrets, the rake task list) is an
  # argument or a stub.
  let(:stripe_postmark) do
    { 'payment_processing' => { 'default_gateway' => 'stripe', 'default_recurring_gateway' => 'stripe' },
      'email' => { 'delivery_method' => 'postmark' } }
  end
  let(:bogus_sendmail) do
    { 'payment_processing' => { 'default_gateway' => 'bogus', 'default_recurring_gateway' => 'bogus' },
      'email' => { 'delivery_method' => 'sendmail' } }
  end

  # Pretend every secret is absent unless the example says otherwise.
  def configure_secrets(*present)
    allow(AppSecrets).to receive(:[]) { |name| 'value' if present.include?(name) }
    allow(AppSecrets).to receive(:blank_env?).and_return(false)
    allow(AppSecrets).to receive(:credentials_status).and_return(:ok)
    allow(Rails.application).to receive(:secrets).and_return({})
  end

  # Everything a fully configured Stripe/Postmark deployment resolves.
  let(:all_secrets) do
    %i[secret_key_base stripe_secret_key postmark_api_token stripe_signing_secret resque_admin_password]
  end

  describe '.required' do
    it 'always requires a secret key base' do
      expect(described_class.required(server_config: bogus_sendmail)).to eq([:secret_key_base])
    end

    it 'adds the Stripe key when either gateway is Stripe' do
      recurring_only = { 'payment_processing' => { 'default_gateway' => 'bogus',
                                                   'default_recurring_gateway' => 'stripe' } }

      expect(described_class.required(server_config: recurring_only)).to include(:stripe_secret_key)
    end

    it 'adds the Postmark token when mail is delivered through Postmark' do
      expect(described_class.required(server_config: stripe_postmark))
        .to eq(%i[secret_key_base stripe_secret_key postmark_api_token])
    end

    it 'reads a configuration with indifferent access' do
      expect(described_class.required(server_config: stripe_postmark.with_indifferent_access))
        .to eq(%i[secret_key_base stripe_secret_key postmark_api_token])
    end

    it 'survives a bare configuration with no payment or email sections' do
      expect(described_class.required(server_config: {})).to eq([:secret_key_base])
    end
  end

  describe '.missing' do
    it 'is empty when every required secret resolves' do
      configure_secrets(:secret_key_base, :stripe_secret_key, :postmark_api_token)

      expect(described_class.missing(server_config: stripe_postmark)).to be_empty
    end

    it 'lists only the required secrets that are absent' do
      configure_secrets(:secret_key_base)

      expect(described_class.missing(server_config: stripe_postmark))
        .to eq(%i[stripe_secret_key postmark_api_token])
    end

    # Rails 6.1 resolves production secret_key_base as ENV || credentials ||
    # secrets.yml, and config/secrets.yml is still in the tree.
    it 'accepts a secret key base that only config/secrets.yml supplies' do
      configure_secrets
      allow(Rails.application).to receive(:secrets).and_return(secret_key_base: 'from_secrets_yml')

      expect(described_class.missing(server_config: bogus_sendmail)).to be_empty
    end

    it 'does not accept a blank secret key base from config/secrets.yml' do
      configure_secrets
      allow(Rails.application).to receive(:secrets).and_return(secret_key_base: '  ')

      expect(described_class.missing(server_config: bogus_sendmail)).to eq([:secret_key_base])
    end
  end

  describe '.warn_only_missing' do
    it 'reports an absent Stripe signing secret without making it fatal' do
      configure_secrets(:secret_key_base, :stripe_secret_key, :postmark_api_token, :resque_admin_password)

      expect(described_class.warn_only_missing(server_config: stripe_postmark)).to eq([:stripe_signing_secret])
      expect(described_class.missing(server_config: stripe_postmark)).to be_empty
    end

    # An unset Resque password means an unauthenticated queue dashboard in
    # development and a dashboard nobody can open in production, so setup:doctor
    # and the boot log should say so -- but neither is worth refusing to boot.
    it 'reports an absent Resque dashboard password whatever the gateway' do
      configure_secrets(:secret_key_base)

      expect(described_class.warn_only_missing(server_config: bogus_sendmail)).to eq([:resque_admin_password])
      expect(described_class.missing(server_config: bogus_sendmail)).to be_empty
    end

    it 'says nothing about Stripe when Stripe is not in use' do
      configure_secrets(:secret_key_base, :resque_admin_password)

      expect(described_class.warn_only_missing(server_config: bogus_sendmail)).to be_empty
    end
  end

  describe '.describe' do
    it 'names the consequence of leaving the secret unset' do
      configure_secrets

      expect(described_class.describe(:resque_admin_password)).to include('/admin/resque')
      expect(described_class.describe(:stripe_signing_secret)).to include('webhooks')
    end
  end

  describe '.check!' do
    before { allow(Kernel).to receive(:warn) }

    it 'passes when everything required is configured' do
      configure_secrets(*all_secrets)

      expect(described_class.check!(server_config: stripe_postmark)).to be(true)
    end

    it 'raises naming the environment variable and the credentials path for each gap' do
      configure_secrets(:secret_key_base)

      expect { described_class.check!(server_config: stripe_postmark) }
        .to raise_error(described_class::Missing) { |error|
              expect(error.message).to match(/STRIPE_SECRET_KEY.*stripe\.secret_key/m)
              expect(error.message).to match(/POSTMARK_API_TOKEN.*postmark_api_token/m)
            }
    end

    it 'points at the blank line when that is what is shadowing the secret' do
      configure_secrets
      allow(AppSecrets).to receive(:blank_env?).with(:secret_key_base).and_return(true)

      expect { described_class.check!(server_config: bogus_sendmail) }
        .to raise_error(described_class::Missing, /present but BLANK -- delete the line/)
    end

    it 'warns rather than raises for the Stripe signing secret' do
      configure_secrets(:secret_key_base, :stripe_secret_key, :postmark_api_token, :resque_admin_password)

      described_class.check!(server_config: stripe_postmark)

      expect(Kernel).to have_received(:warn).with(/STRIPE_SIGNING_SECRET/)
    end

    # With the .enc present and no key, every credential reads as nil, so the
    # per-secret advice ("add the credential") is advice the operator already
    # took. Lead with the real diagnosis.
    it 'leads with the undecryptable-credentials diagnosis when there is no key' do
      configure_secrets
      allow(AppSecrets).to receive(:credentials_status).and_return(:no_key)
      allow(AppSecrets).to receive(:credentials_file).and_return('config/credentials/production.yml.enc')

      expect { described_class.check!(server_config: bogus_sendmail) }
        .to raise_error(described_class::Missing) { |error|
              expect(error.message.lines.first)
                .to match(%r{config/credentials/production\.yml\.enc exists but no decryption key})
              expect(error.message).to include('RAILS_MASTER_KEY')
            }
    end

    it 'says nothing about decryption keys when the credentials are readable' do
      configure_secrets

      expect { described_class.check!(server_config: bogus_sendmail) }
        .to raise_error(described_class::Missing, /\ARefusing to boot/)
    end
  end

  describe '.enforce?' do
    # Passenger never loads Rake, so an empty task list means a web (or spec)
    # process -- enforce.
    it 'enforces outside Rake' do
      expect(described_class.enforce?(env: {}, tasks: [], console: false)).to be(true)
    end

    it 'stands down for a deploy task such as assets:precompile' do
      expect(described_class.enforce?(env: {}, tasks: ['assets:precompile'], console: false)).to be(false)
    end

    it 'stands down for db:migrate and the setup tasks' do
      expect(described_class.enforce?(env: {}, tasks: %w[db:migrate], console: false)).to be(false)
      expect(described_class.enforce?(env: {}, tasks: %w[setup:config], console: false)).to be(false)
    end

    # script/resque-worker boots workers with `rake environment resque:work`,
    # and a worker with no secrets is as broken as a web process with none.
    it 'enforces for the Resque worker, which also boots through Rake' do
      expect(described_class.enforce?(env: {}, tasks: %w[environment resque:work], console: false)).to be(true)
    end

    it 'stands down in a console or runner' do
      expect(described_class.enforce?(env: {}, tasks: [], console: true)).to be(false)
    end

    it 'stands down when the escape hatch is set' do
      expect(described_class.enforce?(env: { 'SKIP_REQUIRED_SECRETS_CHECK' => '1' }, tasks: [], console: false))
        .to be(false)
    end

    it 'ignores a blank escape hatch, as it does every other blank variable' do
      expect(described_class.enforce?(env: { 'SKIP_REQUIRED_SECRETS_CHECK' => '' }, tasks: [], console: false))
        .to be(true)
    end
  end

  # The arguments above document the decision table; these exercise the sniffing
  # that supplies those arguments in a real process.
  describe '.enforce? environment detection' do
    def with_rake(tasks)
      stub_const('Rake', double('Rake', application: double('Rake::Application', top_level_tasks: tasks)))
    end

    it 'reads the running task list from Rake' do
      with_rake(%w[environment resque:work])

      expect(described_class.enforce?(env: {})).to be(true)
    end

    it 'stands down when Rake is running something else' do
      with_rake(%w[assets:precompile])

      expect(described_class.enforce?(env: {})).to be(false)
    end

    # A Rake application that was never invoked from the command line has no
    # top-level tasks -- that is a web process that merely loaded the gem.
    it 'enforces when Rake is loaded but was never invoked' do
      with_rake([])

      expect(described_class.enforce?(env: {})).to be(true)
    end

    it 'enforces when Rake is not loaded at all, as inside Passenger' do
      hide_const('Rake')

      expect(described_class.enforce?(env: {})).to be(true)
    end

    it 'detects `rails console`' do
      hide_const('Rake')
      stub_const('Rails::Console', Class.new)

      expect(described_class.enforce?(env: {})).to be(false)
    end

    it 'detects `rails runner`' do
      hide_const('Rake')
      stub_const('Rails::Command::RunnerCommand', Class.new)

      expect(described_class.enforce?(env: {})).to be(false)
    end
  end
end
