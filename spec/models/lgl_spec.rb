# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl do
  after { described_class.reset! }

  describe '.disable' do
    it 'is not enabled and writes nothing' do
      described_class.configure('key').disable

      expect(described_class).not_to be_enabled
      expect(described_class.writable?(5)).to be(false)
    end

    it 'refuses to hand out a client' do
      described_class.disable

      expect { described_class.client }.to raise_error(Lgl::Error, /not configured/)
    end
  end

  describe '.configure' do
    it 'treats a blank key as not configured' do
      described_class.configure('  ')

      expect(described_class).not_to be_enabled
    end

    it 'memoises the client' do
      described_class.configure('key')

      expect(described_class.client).to be_a(Lgl::Client).and equal(described_class.client)
    end
  end

  describe '.read_only!' do
    before { described_class.configure('key') }

    it 'blocks writes for every address when no allowlist is given' do
      described_class.read_only!

      expect(described_class).to be_read_only
      expect(described_class.writable?(5)).to be(false)
    end

    it 'allows addresses listed in a comma-separated string' do
      described_class.read_only!(except_address_ids: ' 5, 12 ,,')

      expect(described_class.writable?(5)).to be(true)
      expect(described_class.writable?('12')).to be(true)
      expect(described_class.writable?(6)).to be(false)
    end

    it 'accepts an array of ids' do
      described_class.read_only!(except_address_ids: [7, '8'])

      expect(described_class.writable_address_ids).to eq(Set[7, 8])
    end

    it 'never allows writes while disabled, even for an allowlisted address' do
      described_class.read_only!(except_address_ids: '5')
      described_class.disable

      expect(described_class.writable?(5)).to be(false)
    end
  end

  describe '.read_write!' do
    it 'allows writes for any address once configured' do
      described_class.configure('key').read_only!
      described_class.read_write!

      expect(described_class).not_to be_read_only
      expect(described_class.writable?(99)).to be(true)
    end
  end

  describe '.configure_from' do
    def settings(sync: 'enabled', ids: nil)
      Lgl::Settings.from({ 'littlegreenlight' => { 'sync' => sync, 'writable_address_ids' => ids } }, env: {})
    end

    def configure(environment, api_key: 'key', **options)
      described_class.configure_from(settings(**options), api_key: api_key, environment: environment)
    end

    %w[development production staging].each do |environment|
      context "in #{environment}" do
        %w[disabled bogus].each do |word|
          it "is disabled when sync is #{word.inspect}, even with a key" do
            configure(environment, sync: word)

            expect(described_class).not_to be_enabled
          end
        end

        %w[enabled readonly].each do |word|
          it "is disabled without a key, even with sync #{word}" do
            configure(environment, sync: word, api_key: ' ')

            expect(described_class).not_to be_enabled
          end
        end

        it 'is read-only for every address in readonly mode with no allowlist' do
          configure(environment, sync: 'readonly')

          expect(described_class).to be_enabled.and be_read_only
          expect(described_class.writable?(5)).to be(false)
        end

        it 'is read-only except the listed ids in readonly mode with an allowlist' do
          configure(environment, sync: 'readonly', ids: '5, 12')

          expect(described_class).to be_enabled.and be_read_only
          expect(described_class.writable_address_ids).to eq(Set[5, 12])
          expect(described_class.writable?(5)).to be(true)
          expect(described_class.writable?(6)).to be(false)
        end
      end
    end

    context 'when sync is enabled in development' do
      before { allow(Rails.logger).to receive(:info) }

      it 'downgrades to read-only for every address and logs it once' do
        configure('development')

        expect(described_class).to be_enabled.and be_read_only
        expect(described_class.writable?(5)).to be(false)
        expect(Rails.logger).to have_received(:info)
          .with("[LGL] sync 'enabled' downgraded to readonly in development").once
      end

      it 'keeps the allowlist when downgraded' do
        configure('development', ids: '5')

        expect(described_class).to be_read_only
        expect(described_class.writable?(5)).to be(true)
        expect(described_class.writable?(6)).to be(false)
      end
    end

    it 'does not log a downgrade in readonly mode' do
      allow(Rails.logger).to receive(:info)

      configure('development', sync: 'readonly')

      expect(Rails.logger).not_to have_received(:info).with(a_string_including('downgraded'))
    end

    %w[production staging].each do |environment|
      it "makes #{environment} fully writable when sync is enabled" do
        configure(environment)

        expect(described_class).to be_enabled
        expect(described_class).not_to be_read_only
        expect(described_class.writable?(5)).to be(true)
      end

      it "ignores the allowlist in #{environment} when sync is enabled" do
        configure(environment, ids: '5, 12')

        expect(described_class).not_to be_read_only
        expect(described_class.writable_address_ids).to be_empty
        expect(described_class.writable?(6)).to be(true)
      end
    end

    it 'always disables the test environment' do
      configure('test', ids: '5')

      expect(described_class).not_to be_enabled
      expect(described_class.writable?(5)).to be(false)
    end

    it 'remembers the settings it was configured from' do
      given = settings(ids: '7')
      described_class.configure_from(given, api_key: 'key', environment: 'production')

      expect(described_class.settings).to equal(given)
    end
  end

  describe '.log_disabled' do
    it 'logs one info line naming both switches and returns nil' do
      allow(Rails.logger).to receive(:info)

      expect(described_class.log_disabled('poll')).to be_nil
      expect(Rails.logger).to have_received(:info)
        .with(a_string_including('[LGL] poll skipped', 'littlegreenlight.sync', 'LGL_API_KEY')).once
    end
  end

  describe '.constituent_url' do
    def with_web_url(value)
      config = Rails.configuration.x.server_config.deep_dup
      config['littlegreenlight'] = { 'web_url' => value }
      allow(Rails.configuration.x).to receive(:server_config).and_return(config)
    end

    it 'is nil when no LGL web URL is configured (as in the test config)' do
      expect(described_class.constituent_url(42)).to be_nil
    end

    it 'builds the constituent page under littlegreenlight.web_url' do
      with_web_url('https://house.littlegreenlight.com/')

      expect(described_class.constituent_url('42')).to eq('https://house.littlegreenlight.com/constituents/42')
    end

    it 'no longer reads the old lgl: section' do
      config = Rails.configuration.x.server_config.deep_dup
      config['lgl'] = { 'web_url' => 'https://house.littlegreenlight.com' }
      allow(Rails.configuration.x).to receive(:server_config).and_return(config)

      expect(described_class.constituent_url('42')).to be_nil
    end

    it 'is nil for a blank id' do
      with_web_url('https://house.littlegreenlight.com')

      expect(described_class.constituent_url(nil)).to be_nil
    end
  end
end
