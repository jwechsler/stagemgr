# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn
  password credit_card_number card_number credit_card_verification_number
  credit_card_expiration_month credit_card_expiration_year
]
