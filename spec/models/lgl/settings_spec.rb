# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::Settings do
  def settings(section = nil, env: {})
    described_class.from(section.nil? ? {} : { 'littlegreenlight' => section }, env: env)
  end

  describe 'sync' do
    it 'is disabled when the section is missing' do
      expect(settings).not_to be_sync_enabled
      expect(settings.sync_source).to eq(:none)
    end

    it 'is enabled by "enabled" in server.yml, ignoring case and spaces' do
      result = settings({ 'sync' => ' Enabled ' })

      expect(result).to be_sync_enabled
      expect(result.sync_source).to eq(:server_yml)
    end

    ['disabled', 'true', 'yes', 'on', true, 1].each do |value|
      it "is disabled by #{value.inspect}" do
        expect(settings({ 'sync' => value })).not_to be_sync_enabled
      end
    end

    it 'lets a non-blank LGL_SYNC override server.yml' do
      result = settings({ 'sync' => 'enabled' }, env: { 'LGL_SYNC' => 'disabled' })

      expect(result).not_to be_sync_enabled
      expect(result.sync_source).to eq(:env)
    end

    it 'turns sync on from LGL_SYNC alone' do
      expect(settings(env: { 'LGL_SYNC' => 'enabled' })).to be_sync_enabled
    end

    it 'ignores a blank LGL_SYNC' do
      result = settings({ 'sync' => 'enabled' }, env: { 'LGL_SYNC' => '  ' })

      expect(result).to be_sync_enabled
      expect(result.sync_source).to eq(:server_yml)
    end

    it 'reads symbol keys too' do
      expect(described_class.from({ littlegreenlight: { sync: 'enabled' } }, env: {})).to be_sync_enabled
    end
  end

  describe 'writable_address_ids' do
    it 'is nil when unset everywhere' do
      expect(settings({ 'writable_address_ids' => nil }).writable_address_ids).to be_nil
      expect(settings.writable_address_ids_source).to eq(:none)
    end

    it 'parses a comma-separated string' do
      result = settings({ 'writable_address_ids' => ' 5, 12 ,,' })

      expect(result.writable_address_ids).to eq(Set[5, 12])
      expect(result.writable_address_ids_source).to eq(:server_yml)
    end

    it 'parses a YAML list' do
      expect(settings({ 'writable_address_ids' => [7, '8'] }).writable_address_ids).to eq(Set[7, 8])
    end

    it 'parses a single integer' do
      expect(settings({ 'writable_address_ids' => 42 }).writable_address_ids).to eq(Set[42])
    end

    it 'treats an empty list as unset' do
      expect(settings({ 'writable_address_ids' => [] }).writable_address_ids).to be_nil
    end

    it 'gives an empty Set (read-only for everyone) when nothing parses' do
      expect(settings({ 'writable_address_ids' => 'abc, 12a' }).writable_address_ids).to eq(Set[])
    end

    it 'lets a non-blank LGL_WRITABLE_ADDRESS_IDS override server.yml' do
      result = settings({ 'writable_address_ids' => '5' }, env: { 'LGL_WRITABLE_ADDRESS_IDS' => '9,10' })

      expect(result.writable_address_ids).to eq(Set[9, 10])
      expect(result.writable_address_ids_source).to eq(:env)
    end

    it 'ignores a blank LGL_WRITABLE_ADDRESS_IDS' do
      result = settings({ 'writable_address_ids' => '5' }, env: { 'LGL_WRITABLE_ADDRESS_IDS' => '' })

      expect(result.writable_address_ids).to eq(Set[5])
    end
  end

  describe 'web_url' do
    it 'drops a trailing slash' do
      expect(settings({ 'web_url' => 'https://house.littlegreenlight.com/ ' }).web_url)
        .to eq('https://house.littlegreenlight.com')
    end

    it 'is nil when blank' do
      expect(settings({ 'web_url' => '' }).web_url).to be_nil
    end
  end

  it 'reads the test block of config/server.yml.example as disabled' do
    expect(described_class.from(Rails.configuration.x.server_config, env: {})).not_to be_sync_enabled
  end
end
