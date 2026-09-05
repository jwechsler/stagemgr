# frozen_string_literal: true

# Plain require rather than require_relative: the path is inside an autoload
# path, so Zeitwerk still manages the constant and no `ignore` entry is needed.
# Explicit because this file must not depend on some other initializer having
# sorted before it and loaded lib/*.rb along the way.
require Rails.root.join('lib/site_theme').to_s

# Activates the site theme named by `site_theme:` in config/server.yml, so that
# sites/<slug>/views/** shadows app/views/** for pages and mail alike, and
# sites/<slug>/locales/*.yml win over config/locales. See sites/README.md.
#
# Registered with ActiveSupport.on_load rather than a to_prepare hook: Rails'
# own add_view_paths initializer uses the same hooks and runs before
# load_config_initializers, so a path prepended here lands ahead of app/views --
# and, unlike to_prepare, it does not re-run (and re-prepend) on every reload in
# development. The respond_to? guard mirrors that initializer: the
# :action_controller hook also fires for ActionController::API, which renders no
# views and has no prepend_view_path.
#
# Tolerance is deliberate and asymmetric. A malformed slug raises from
# SiteTheme.slug and stops the boot, because it is always a typo or an attempt
# to escape sites/. A slug whose directory is simply absent only warns and the
# app serves generic copy: a production checkout must keep booting when sites/
# has not been deployed to it.
theme = SiteTheme.slug

if theme.present?
  if SiteTheme.views_available?(theme)
    views = SiteTheme.views_path(theme).to_s
    ActiveSupport.on_load(:action_controller) { prepend_view_path(views) if respond_to?(:prepend_view_path) }
    ActiveSupport.on_load(:action_mailer) { prepend_view_path(views) }

    locales = SiteTheme.locale_files(theme)
    Rails.application.config.i18n.load_path += locales if locales.any?

    Rails.logger&.info do
      "[SiteTheme] '#{theme}' active: views from #{views}#{", #{locales.size} locale file(s)" if locales.any?}"
    end
  else
    message = "[SiteTheme] site_theme '#{theme}' is configured but #{SiteTheme.views_path(theme)} does not " \
              'exist; serving generic copy. Run `rake setup:site[' \
              "#{theme}]` to create it, or clear site_theme in config/server.yml."
    Rails.logger&.warn(message)
    # Also on stderr for someone watching a console start, but not into the logs
    # of a Passenger or Resque process, where the line above already covers it.
    Kernel.warn(message) if $stderr.tty?
  end
end
