# Deprecated compatibility shim: these globals alias Rails.configuration.x.*;
# new code must use the configuration form. Remove after external forks migrate.
#
# Each global below points at the IDENTICAL object stored on
# Rails.application.config.x.* by the environment files (and config/application.rb
# for the markdown renderers). They exist only so that any missed or dynamically
# constructed reference keeps working during the transition. Do not add new
# usages of these globals.
#
# This file runs before other config/initializers (alphabetical load order), so
# globals read at initializer load time (e.g. resque_auth.rb) still resolve.
#
# $MARKDOWN / $TRUSTED_MARKDOWN are aliased in config/application.rb instead,
# because their config.x.* values are populated by a late initializer that runs
# after config/initializers are loaded.

$SERVER_CONFIG         = Rails.configuration.x.server_config
$TKTPRINT              = Rails.configuration.x.tktprint
$EMAIL_ADDRESS         = Rails.configuration.x.email_address
$PAYMENT_CONFIG        = Rails.configuration.x.payment_config
$ADDITIONAL_CARD_TYPES = Rails.configuration.x.additional_card_types
$RAND_CLAUSE           = Rails.configuration.x.rand_clause
$TEST_CREDIT_CARD      = Rails.configuration.x.test_credit_card
$APP_DISPLAY_NAME      = Rails.configuration.x.app_display_name
