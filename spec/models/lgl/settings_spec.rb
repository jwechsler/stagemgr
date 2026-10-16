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

    it 'is disabled, with no word, when the section is missing' do
      expect(settings.sync_mode).to eq(:disabled)
      expect(settings.sync_value).to be_nil
      expect(settings).to be_sync_value_recognized
    end

    it 'is enabled by "enabled" in server.yml, ignoring case and spaces' do
      result = settings({ 'sync' => ' Enabled ' })

      expect(result.sync_mode).to eq(:enabled)
      expect(result).to be_sync_enabled
      expect(result).not_to be_read_only_mode
      expect(result.sync_source).to eq(:server_yml)
    end

    it 'is readonly by "readonly", ignoring case and spaces, and counts as sync on' do
      result = settings({ 'sync' => ' ReadOnly ' })

      expect(result.sync_mode).to eq(:readonly)
      expect(result).to be_sync_enabled.and be_read_only_mode
      expect(result).to be_sync_value_recognized
    end

    it 'is disabled by "disabled" and recognises the word' do
      result = settings({ 'sync' => 'Disabled' })

      expect(result.sync_mode).to eq(:disabled)
      expect(result).not_to be_sync_enabled
      expect(result).not_to be_read_only_mode
      expect(result).to be_sync_value_recognized
    end

    ['true', 'yes', 'on', 'read-only', 'read_only', true, 1].each do |value|
      it "is disabled by the unknown word #{value.inspect}" do
        result = settings({ 'sync' => value })

        expect(result.sync_mode).to eq(:disabled)
        expect(result).not_to be_sync_enabled
        expect(result).not_to be_sync_value_recognized
        expect(result.sync_value).to eq(value.to_s)
      end
    end

    it 'takes readonly from LGL_SYNC over server.yml' do
      result = settings({ 'sync' => 'enabled' }, env: { 'LGL_SYNC' => 'readonly' })

      expect(result.sync_mode).to eq(:readonly)
      expect(result.sync_source).to eq(:env)
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

  describe 'donor_tier_report_url' do
    let(:url) { 'https://house.littlegreenlight.com/reports/abc' }

    it 'reads the url from server.yml, stripped' do
      result = settings({ 'donor_tier_report_url' => " #{url} " })

      expect(result.donor_tier_report_url).to eq(url)
      expect(result.donor_tier_report_url_source).to eq(:server_yml)
      expect(result).to be_donor_levels_enabled
    end

    it 'lets a non-blank LGL_DONOR_TIER_REPORT_URL override server.yml' do
      result = settings({ 'donor_tier_report_url' => url }, env: { 'LGL_DONOR_TIER_REPORT_URL' => "#{url}2" })

      expect(result.donor_tier_report_url).to eq("#{url}2")
      expect(result.donor_tier_report_url_source).to eq(:env)
    end

    it 'ignores a blank LGL_DONOR_TIER_REPORT_URL' do
      result = settings({ 'donor_tier_report_url' => url }, env: { 'LGL_DONOR_TIER_REPORT_URL' => ' ' })

      expect(result.donor_tier_report_url).to eq(url)
    end

    it 'is nil, and donor levels are off, when blank everywhere' do
      result = settings({ 'donor_tier_report_url' => '  ' })

      expect(result.donor_tier_report_url).to be_nil
      expect(result.donor_tier_report_url_source).to eq(:none)
      expect(result).not_to be_donor_levels_enabled
    end
  end

  describe 'donor_flag_excluded_tiers' do
    it 'reads a YAML list, stripped' do
      result = settings({ 'donor_flag_excluded_tiers' => [' Up to $99.99 ', '$100-$249.99'] })

      expect(result.donor_flag_excluded_tiers).to eq(['Up to $99.99', '$100-$249.99'])
      expect(result.donor_flag_excluded_tiers).to be_frozen
    end

    it 'turns a single string into a one-element list' do
      expect(settings({ 'donor_flag_excluded_tiers' => 'Up to $99.99' }).donor_flag_excluded_tiers)
        .to eq(['Up to $99.99'])
    end

    it 'is an empty list when unset' do
      expect(settings({}).donor_flag_excluded_tiers).to eq([])
      expect(settings.donor_flag_excluded_tiers).to eq([])
    end

    it 'drops blank entries' do
      expect(settings({ 'donor_flag_excluded_tiers' => ['Up to $99.99', '', '  ', nil] }).donor_flag_excluded_tiers)
        .to eq(['Up to $99.99'])
    end

    it 'is read when sync is disabled' do
      result = settings({ 'sync' => 'disabled', 'donor_flag_excluded_tiers' => ['Up to $99.99'] })

      expect(result.donor_flag_excluded_tiers).to eq(['Up to $99.99'])
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

  it 'reads the test block of config/server.yml.example as disabled, with no donor report' do
    result = described_class.from(Rails.configuration.x.server_config, env: {})

    expect(result.sync_mode).to eq(:disabled)
    expect(result).not_to be_donor_levels_enabled
  end
end
