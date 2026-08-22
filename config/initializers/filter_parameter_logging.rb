# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn
  password credit_card_number card_number credit_card_verification_number
  credit_card_expiration_month credit_card_expiration_year
]

# Authlogic's session cookie value is the live persistence_token: with a forged
# signed cookie it is a session-hijack primitive. It reaches @request.filtered_env
# -- and so ExceptionNotifier's Environment section -- under several keys
# (rack.session, action_dispatch.request.unsigned_session_cookie,
# rack.request.cookie_hash).
#
# Anchored, unlike the plain strings above, which match as substrings: filtering
# 'user_credentials' loosely would also mask 'user_credentials_id', and the user
# id is diagnostically useful, not secret. Raw Cookie header strings are not
# key-matchable and are handled by ExceptionSecretRedactor instead.
Rails.application.config.filter_parameters += [/\Auser_credentials\z/]
