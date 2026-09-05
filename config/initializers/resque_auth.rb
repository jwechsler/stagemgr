# frozen_string_literal: true

# Basic auth on the mounted Resque web UI (config/routes.rb mounts it at
# /admin/resque with no other authentication in front of it).
#
# The password comes from RESQUE_ADMIN_PASSWORD or the credentials; a
# `resque_admin_password:` still sitting in server.yml keeps working but warns
# once at boot (see AppSecrets).
module ResqueAuth
  DENIED = 'is unauthenticated and has been DENIED to everyone. Set RESQUE_ADMIN_PASSWORD ' \
           '(or the resque_admin_password credential) and restart to use it.'

  # Returns :password, :denied or :open -- what was installed, for the log and
  # for spec/config/resque_auth_spec.rb.
  def self.install(server, password:, production:)
    if password
      server.use(Rack::Auth::Basic) do |_user, given|
        ActiveSupport::SecurityUtils.secure_compare(given.to_s, password)
      end
      :password
    elsif production
      # Fail closed. An open queue dashboard exposes job arguments (order ids,
      # email addresses) and offers a one-click "Clear failed jobs" button, so
      # the safe answer to "no password configured" in production is "nobody".
      server.use(Rack::Auth::Basic) { |_user, _given| false }
      warn_denied
      :denied
    else
      :open
    end
  end

  def self.warn_denied
    message = "[ResqueAuth] /admin/resque #{DENIED}"
    Kernel.warn(message)
    Rails.logger.warn(message) if Rails.logger
  end
end

ResqueAuth.install(Resque::Server,
                   password: AppSecrets[:resque_admin_password],
                   production: Rails.env.production?)
