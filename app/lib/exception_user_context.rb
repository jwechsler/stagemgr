# "Who was using the app when this blew up?", resolved from the raw Rack env for
# the ExceptionNotifier "User" section (app/views/exception_notifier/_user.text.erb).
#
# Why not UserSession.find or controller.current_user?
#   Authlogic needs an activated controller (RequestStore[:authlogic_controller],
#   set by prepend_before_action :activate_authlogic). Exceptions raised in Rack
#   middleware -- the whole reason this lives here rather than in a before_action
#   -- never reach that callback, so UserSession.find would raise
#   NotActivatedError or, worse, answer from a previous request's controller.
#   Reading the session we were handed is deterministic in both notification
#   paths (ApplicationController#handle_exception and ExceptionNotification::Rack).
#
# This class must never raise. ExceptionNotifier's exception_notification.text.erb
# does rescue per section, but a failure here would replace real diagnostics with
# a rendering backtrace.
class ExceptionUserContext
  # Authlogic defaults for UserSession: session_key -> cookie_key ->
  # "#{klass_name.underscore}_credentials", and session_compound_key ->
  # "#{session_key}_#{primary_key}". Hardcoded rather than asked of Authlogic at
  # load time because User.primary_key queries the schema, and this class has to
  # work when the database is what failed. spec/lib/exception_user_context_spec.rb
  # asserts these still agree with Authlogic's config.
  SESSION_TOKEN_KEY = 'user_credentials'.freeze
  SESSION_USER_ID_KEY = 'user_credentials_id'.freeze

  ANONYMOUS = 'Anonymous (no signed-in user)'.freeze

  # Ordered [label, value] pairs, ready for the email. Never empty, never raises.
  attr_reader :fields, :user

  def self.from_env(env)
    new(env)
  end

  def initialize(env)
    @user = nil
    @fields = []
    build(env)
  rescue StandardError => e
    # Accumulating into @fields rather than returning a list means a failure here
    # keeps whatever we had already established -- above all the session user id,
    # which is the whole report when the database is what broke.
    @fields << ['Permission', 'unknown'] if @fields.none? { |label, _value| label == 'Permission' }
    @fields << ['Note', "user context lookup failed: #{e.class}: #{e.message}"]
  end

  def email
    user&.email
  end

  private

  def build(env)
    session = session_from(env)
    session_user_id = session && session[SESSION_USER_ID_KEY]
    return @fields << ['Permission', ANONYMOUS] if session_user_id.blank?

    # Recorded before any database access, so a DB outage still names the actor.
    @fields << ['Session user id', session_user_id.to_s]
    @user = User.find_by(id: session_user_id)
    return @fields << ['Note', 'no such user -- stale or forged session cookie'] if user.nil?

    add_user_fields
    add_session_warnings(session)
  end

  def add_user_fields
    @fields << ['Email', user.email]
    @fields << ['Permission', permission_label]
    @fields << ['Theaters', theater_names] if user.is_theater_user?
    @fields << ['Status', user.status] unless user.status == User::ACTIVE
  end

  # Reasons current_user would have been nil for this request even though the
  # cookie named a real user. Without these the email would confidently
  # attribute an anonymous request to a signed-out person.
  def add_session_warnings(session)
    unless user.persistence_token == session[SESSION_TOKEN_KEY].to_s
      @fields << ['Note', 'session persistence token does not match -- this request was NOT authenticated']
    end
    # Authlogic's logged_in? is also false when last_request_at is NULL, which
    # means "never made a tracked request", not "timed out" -- don't cry wolf.
    return unless user.last_request_at.present? && !user.logged_in?

    @fields << ['Note', 'session had timed out (last_request_at older than the 6 hour idle limit)']
  end

  def permission_label
    label = user.permission_level
    label += ' (resident)' if user.is_resident?
    # is_theater_user? is !admin && !box_office, so both flags set silently
    # collapses to the box-office tier in Ability. Say so out loud.
    label += ' -- also flagged Administrator' if user.is_box_office_user? && user.is_administrator?
    label
  end

  def theater_names
    names = user.theaters.map(&:name).compact.sort
    names.empty? ? '(none assigned)' : names.join(', ')
  end

  # env['rack.session'] is an ActionDispatch::Request::Session in both
  # notification paths (the session store middleware wraps
  # ExceptionNotification::Rack, which config.middleware.use appends innermost),
  # and a plain Hash in specs. Both answer #[] with string keys.
  def session_from(env)
    env && env['rack.session']
  rescue StandardError
    nil
  end
end
