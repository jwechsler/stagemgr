# Strips secrets out of what ExceptionNotifier prints into an email. Used by the
# shadowed app/views/exception_notifier/_session.text.erb and
# _environment.text.erb partials.
#
# The gem dumps the session hash and the whole Rack env. Between them that
# publishes Authlogic's "user_credentials" -- the live persistence_token, which
# together with a forged signed cookie is a session-hijack primitive -- in five
# places: the session dump, env['rack.session'],
# env['action_dispatch.request.unsigned_session_cookie'],
# env['rack.request.cookie_hash'], and the raw HTTP_COOKIE /
# env['rack.request.cookie_string'] strings. All of it lands in plaintext in the
# bugs@ inbox and in every mail relay log on the way.
#
# Two mechanisms are needed, because the leaks come in two shapes:
#
#   Hash entries keyed 'user_credentials' are handled by Rails itself --
#   config/initializers/filter_parameter_logging.rb adds an anchored
#   /\Auser_credentials\z/ to config.filter_parameters, so @request.filtered_env
#   has already masked them (and nothing can log them either). Anchored so that
#   'user_credentials_id' survives: the user id is diagnostically useful, is not
#   a secret, and is what the User section reports.
#
#   Raw cookie strings are not key-matchable -- the secret is embedded in a
#   longer value under a key like HTTP_COOKIE -- so #env scrubs those here.
#
# Keys are matched exactly, never by substring. This class must never raise; see
# ExceptionUserContext for the same contract.
class ExceptionSecretRedactor
  FILTERED = '[FILTERED]'.freeze

  # Authlogic persistence_token, plus the CSRF token: the gem's raw PP.pp of the
  # session bypasses config.filter_parameters, which only covers the request's
  # filtered_parameters and filtered_env.
  SECRET_SESSION_KEYS = [
    ExceptionUserContext::SESSION_TOKEN_KEY,
    '_csrf_token'
  ].freeze

  # "user_credentials=<token>::<id>" inside a Cookie header. The id goes with it;
  # it is still reported by the User section and by rack.session.
  COOKIE_PATTERN = /(#{Regexp.escape(ExceptionUserContext::SESSION_TOKEN_KEY)}=)[^;]*/

  # A plain Hash, safe to print. Only top-level keys are examined; this app does
  # not nest anything secret inside the session.
  def self.session(session)
    hash = session.respond_to?(:to_hash) ? session.to_hash : {}
    hash.each_with_object({}) do |(key, value), redacted|
      redacted[key] = SECRET_SESSION_KEYS.include?(key.to_s) ? FILTERED : value
    end
  rescue StandardError => e
    { 'session' => "could not be read: #{e.class}: #{e.message}" }
  end

  # Masks both shapes of leak in a Rack env, without relying on the caller having
  # filtered anything. @request.filtered_env only applies config.filter_parameters
  # when env['action_dispatch.parameter_filter'] is set (Rails::Application#env_config
  # sets it for requests reaching the app, but middleware above Rails has no such
  # guarantee), so doing the key masking here too is what makes this dependable.
  def self.env(env)
    env.each_with_object({}) do |(key, value), scrubbed|
      scrubbed[key] = scrub(value)
    end
  rescue StandardError
    env
  end

  def self.scrub(value)
    case value
    when String then value.gsub(COOKIE_PATTERN, "\\1#{FILTERED}")
    when Hash then mask_secret_keys(value)
    else value
    end
  end

  def self.mask_secret_keys(hash)
    hash.each_with_object({}) do |(key, value), masked|
      masked[key] = SECRET_SESSION_KEYS.include?(key.to_s) ? FILTERED : scrub(value)
    end
  end
end
