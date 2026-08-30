require 'rails_helper'

RSpec.describe MailerUrlOptions do
  describe '.for' do
    let(:server_config) do
      { 'host' => 'www.example.org', 'host_protocol' => 'https', 'sub_uri' => '/tickets' }
    end

    it 'carries the host and protocol from the server configuration' do
      options = described_class.for(server_config)

      expect(options).to include(host: 'www.example.org', protocol: 'https')
    end

    it 'passes the sub-URI mount as :script_name rather than folding it into the host' do
      options = described_class.for(server_config)

      expect(options[:script_name]).to eq('/tickets')
      expect(options[:host]).not_to include('/tickets')
    end

    it 'omits :script_name for deployments mounted at the root' do
      options = described_class.for(server_config.merge('sub_uri' => ''))

      expect(options).not_to have_key(:script_name)
    end

    it 'falls back to localhost over http when the configuration is empty' do
      options = described_class.for({})

      expect(options).to eq(host: 'localhost', protocol: 'http')
    end

    it 'reads a configuration with indifferent access' do
      options = described_class.for(server_config.with_indifferent_access)

      expect(options).to include(host: 'www.example.org', script_name: '/tickets')
    end
  end
end
