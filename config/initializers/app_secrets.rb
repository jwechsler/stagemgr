# frozen_string_literal: true

# AppSecrets and RequiredSecrets are required from config/application.rb (they
# have to exist before the environment files run). This initializer only wires
# up what they report at boot.

# Development: say where each secret came from, so a shadowed or missing key is
# visible in the boot log instead of surfacing as a 401 hours later. Sources
# only -- never values.
if Rails.env.development?
  Rails.application.config.after_initialize do
    report = AppSecrets.report
    Rails.logger.info { "[AppSecrets] #{report.map { |name, info| "#{name}=#{info[:source]}" }.join(' ')}" }

    blank = report.values.select { |info| info[:blank_env] }.pluck(:env)
    if blank.any?
      Rails.logger.warn do
        "[AppSecrets] set but blank, so ignored: #{blank.join(', ')}. Delete those lines from .env -- " \
          'a blank value there shadows nothing today but will shadow a real secret the moment one is added.'
      end
    end
  end
end

# Production: refuse to serve with a required secret missing. Skipped for
# consoles, runners and non-resque rake tasks (see RequiredSecrets.enforce?).
#
# Deliberately in the initializer body rather than in an after_initialize hook:
# config.x.server_config is assigned while the environment file loads, which is
# already done by now, and failing here stops the boot before eager loading and
# before the after_initialize hooks that configure the payment gateway and the
# mailer -- the ones that would otherwise fail first, with a worse message.
if Rails.env.production? && RequiredSecrets.enforce?
  RequiredSecrets.check!(server_config: Rails.configuration.x.server_config)
end
