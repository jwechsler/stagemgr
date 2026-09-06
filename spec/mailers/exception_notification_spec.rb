require 'rails_helper'

# The ExceptionNotification middleware is configured only in production.rb, so in
# the test environment ExceptionNotifier.notifiers is empty and notify_exception
# is a no-op. Build the notifier directly instead and render with #create_email,
# which composes the mail without delivering it.
RSpec.describe 'exception notification User section', type: :mailer do
  # Mirrors config/environments/production.rb, minus the sendmail delivery
  # method -- addresses included, so this exercises the same resolution the
  # production environment file performs against server.yml.
  def notifier(sections: %w[user request session environment backtrace])
    addresses = Rails.configuration.x.email_address
    ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Stagemgr Exception] ',
      sender_address: ExceptionRecipients.sender_address(addresses),
      exception_recipients: ExceptionRecipients.for(addresses),
      delivery_method: :test,
      sections: sections
    )
  end

  def env_for(session)
    env = Rack::MockRequest.env_for('/admin/productions', 'HTTP_HOST' => 'stagemgr.test')
    env['rack.session'] = session if session
    env
  end

  def session_for(user)
    { 'user_credentials' => user.persistence_token, 'user_credentials_id' => user.id.to_s }
  end

  # Raised for real so #backtrace is populated for the Backtrace section.
  let(:exception) do
    raise ArgumentError, 'boom'
  rescue ArgumentError => e
    e
  end

  # config/environments/production.rb builds the notifier from these; getting it
  # wrong sends crash reports nowhere, or (with an empty recipient list) raises
  # inside the middleware while it is handling the real exception.
  describe ExceptionRecipients do
    let(:addresses) do
      { 'exception_notifications' => 'bugs@yourtheater.org', 'software_address' => 'stagemgr@yourtheater.org' }
    end

    it 'prefers the dedicated exception address' do
      expect(described_class.for(addresses)).to eq(%w[bugs@yourtheater.org])
    end

    it 'falls back to the software address when no exception address is configured' do
      expect(described_class.for(addresses.except('exception_notifications')))
        .to eq(%w[stagemgr@yourtheater.org])
    end

    it 'treats a blank exception address as unset' do
      expect(described_class.for(addresses.merge('exception_notifications' => '  ')))
        .to eq(%w[stagemgr@yourtheater.org])
    end

    it 'accepts a list of recipients' do
      expect(described_class.for(addresses.merge('exception_notifications' => %w[a@x.org b@x.org])))
        .to eq(%w[a@x.org b@x.org])
    end

    it 'is empty when nothing is configured, which is what suppresses the middleware' do
      expect(described_class.for(nil)).to be_empty
      expect(described_class.for({})).to be_empty
      expect(described_class.sender_address({})).to be_nil
    end

    # The envelope sender stays the application's own address, so bounces and
    # replies land somewhere a human reads rather than in the alert inbox.
    it 'sends as the software address, not as the recipient' do
      expect(described_class.sender_address(addresses)).to eq('"Exception Notifier" <stagemgr@yourtheater.org>')
    end

    it 'falls back to the recipient when there is no software address' do
      expect(described_class.sender_address(addresses.except('software_address')))
        .to eq('"Exception Notifier" <bugs@yourtheater.org>')
    end

    it 'reads the real server.yml configuration with indifferent access' do
      expect(described_class.for(Rails.configuration.x.email_address)).to be_present
    end
  end

  it 'names the acting user and their permission level, ahead of the request details' do
    user = FactoryBot.create(:admin_user)

    body = notifier.create_email(exception, env: env_for(session_for(user))).body.to_s

    expect(body).to include('User:')
    expect(body).to include(user.email)
    expect(body).to include(User::ADMIN)
    expect(body.index('User:')).to be < body.index('Request:')
  end

  # The Session section dumps the session hash and the Environment section dumps
  # the whole Rack env, which between them carried the persistence token in five
  # places. That token plus a forged signed cookie is a session-hijack primitive,
  # and this mail goes to an inbox and through relay logs. Nothing should carry it.
  it 'leaks the persistence token nowhere in a fully populated report' do
    user = FactoryBot.create(:admin_user)
    session = session_for(user)
    env = env_for(session)
    env['HTTP_COOKIE'] = "_passenger_route=105; user_credentials=#{user.persistence_token}%3A%3A#{user.id}"
    env['rack.request.cookie_string'] = env['HTTP_COOKIE']
    env['rack.request.cookie_hash'] = { 'user_credentials' => "#{user.persistence_token}::#{user.id}" }
    env['action_dispatch.request.unsigned_session_cookie'] = session

    body = notifier.create_email(exception, env: env).body.to_s

    expect(body).to include('Session:')
    expect(body).to include('Environment:')
    expect(body).not_to include(user.persistence_token)
    expect(body).to include(ExceptionSecretRedactor::FILTERED)
    # ...while still naming who it was.
    expect(body).to include(user.email)
    expect(body).to include(user.id.to_s)
  end

  it 'reports an anonymous public request without failing' do
    body = notifier.create_email(exception, env: env_for(nil)).body.to_s

    expect(body).to include(ExceptionUserContext::ANONYMOUS)
  end

  # Regression guard: EmailNotifier appends 'data' to whatever :sections says, so
  # listing 'user' must not displace ReportProcessor's report_context.
  it 'still appends the automatic Data section alongside the User section' do
    user = FactoryBot.create(:user)

    body = notifier.create_email(exception, env: env_for(session_for(user)),
                                            data: { report_context: { report_name: 'trg_dump' } }).body.to_s

    expect(body).to include('User:')
    expect(body).to include('Data:')
    expect(body).to include('trg_dump')
  end

  # Documents the wrapper template's per-section rescue, so nobody later deletes
  # ExceptionUserContext's defensive rescue thinking it is dead code.
  it 'survives a resolver that raises, without losing the rest of the report' do
    allow(ExceptionUserContext).to receive(:from_env).and_raise('kaboom')

    body = notifier.create_email(exception, env: env_for(nil)).body.to_s

    expect(body).to include('ERROR: Failed to generate exception summary')
    # Not Backtrace: -- clean_backtrace drops every non-application frame, and an
    # exception raised inside a spec has none, so that section renders blank and
    # the wrapper omits it. Request is the section that proves the mail survived.
    expect(body).to include('Request:')
  end
end
