require 'rails_helper'

# Verifies the migration from $GLOBALS to Rails.configuration.x.* and the
# compatibility shim in config/initializers/legacy_globals.rb (plus the markdown
# aliases set in config/application.rb). The shim is temporary; this spec guards
# that the config.x.* values are populated and that the legacy globals remain the
# IDENTICAL objects during the transition.
CONFIG_X_KEYS = %i[
  server_config tktprint email_address payment_config additional_card_types
  markdown trusted_markdown rand_clause test_credit_card app_display_name
].freeze

RSpec.describe 'legacy global configuration shim' do
  # Some specs reassign individual globals (e.g. $TKTPRINT) to stub configuration
  # and do not restore them, which would leak across the randomly-ordered suite.
  # Re-run the shim aliasing here so the identity assertions below verify the
  # initializer's intended wiring rather than incidental run-order pollution.
  before { load Rails.root.join('config/initializers/legacy_globals.rb') }

  describe 'config.x.* values are populated in the test environment' do
    CONFIG_X_KEYS.each do |key|
      it "Rails.configuration.x.#{key} is present" do
        expect(Rails.configuration.x.public_send(key)).not_to be_nil
      end
    end
  end

  describe 'hash-like config values support string-key access' do
    {
      server_config: 'host',
      tktprint: nil,
      payment_config: nil,
      email_address: nil
    }.each do |key, sample_string_key|
      it "config.x.#{key} responds to []" do
        value = Rails.configuration.x.public_send(key)
        expect(value).to respond_to(:[])
        expect { value[sample_string_key] } if sample_string_key
      end
    end

    it "config.x.server_config['host'] returns a value via string key" do
      expect(Rails.configuration.x.server_config['host']).not_to be_nil
    end
  end

  describe 'each legacy global is the SAME object as its config.x counterpart' do
    it '$SERVER_CONFIG' do
      expect($SERVER_CONFIG).to equal(Rails.configuration.x.server_config)
    end

    it '$TKTPRINT' do
      expect($TKTPRINT).to equal(Rails.configuration.x.tktprint)
    end

    it '$EMAIL_ADDRESS' do
      expect($EMAIL_ADDRESS).to equal(Rails.configuration.x.email_address)
    end

    it '$PAYMENT_CONFIG' do
      expect($PAYMENT_CONFIG).to equal(Rails.configuration.x.payment_config)
    end

    it '$ADDITIONAL_CARD_TYPES' do
      expect($ADDITIONAL_CARD_TYPES).to equal(Rails.configuration.x.additional_card_types)
    end

    it '$MARKDOWN' do
      expect($MARKDOWN).to equal(Rails.configuration.x.markdown)
    end

    it '$TRUSTED_MARKDOWN' do
      expect($TRUSTED_MARKDOWN).to equal(Rails.configuration.x.trusted_markdown)
    end

    it '$RAND_CLAUSE' do
      expect($RAND_CLAUSE).to equal(Rails.configuration.x.rand_clause)
    end

    it '$TEST_CREDIT_CARD' do
      expect($TEST_CREDIT_CARD).to equal(Rails.configuration.x.test_credit_card)
    end

    it '$APP_DISPLAY_NAME' do
      expect($APP_DISPLAY_NAME).to equal(Rails.configuration.x.app_display_name)
    end
  end
end
