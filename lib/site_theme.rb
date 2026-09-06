# frozen_string_literal: true

# The in-repo site theme: a directory of view overrides (and, for exactly one
# string today, a locale file) that carries one house's editorial copy.
#
# Selected by `site_theme:` in config/server.yml. Any file under
# sites/<slug>/views/ shadows the same relative path under app/views/ -- public
# pages, mailer templates and layouts alike -- because the theme directory is
# prepended to the view paths of both ActionController::Base and
# ActionMailer::Base at boot (see config/initializers/site_theme.rb).
# sites/<slug>/locales/*.yml are appended to I18n.load_path, so their keys win
# over config/locales.
#
# Why a directory in this repository rather than a database column or a
# deployment-time mount: house copy is editorial, it is reviewed, and it should
# promote with a git branch like any other change. See sites/README.md.
#
# This module is deliberately free of side effects. The initializer decides
# whether to install anything; #with_theme exists so specs can prove a theme's
# templates still compile without leaving it installed for the rest of the run.
module SiteTheme
  # Raised for a slug that is not a bare directory name. Anything else could
  # escape sites/ ("../../etc"), so this is a boot-blocking error rather than a
  # warning: a malformed slug is always a typo or an attack, never a deployment
  # that should be allowed to serve generic pages.
  class InvalidSlug < ArgumentError; end

  SLUG_FORMAT = /\A[a-z0-9_-]+\z/
  DIRECTORY = 'sites'
  VIEWS_SUBDIRECTORY = 'views'
  LOCALES_GLOB = 'locales/*.{rb,yml}'

  class << self
    # The configured slug, or nil when no theme is selected (the generic site).
    # Raises InvalidSlug when the configured value is malformed.
    def slug(server_config = default_server_config)
      raw = lookup(server_config, 'site_theme')
      return nil if raw.blank?

      validate!(raw)
    end

    # The slug, verified. Returns the normalized string so callers can use the
    # return value rather than the argument they passed in.
    def validate!(value)
      candidate = value.to_s.strip
      return candidate if candidate.match?(SLUG_FORMAT)

      raise InvalidSlug,
            "Invalid site_theme #{value.inspect} in config/server.yml. A theme slug is the name of a " \
            'directory under sites/ and may contain only lowercase letters, digits, hyphens and underscores.'
    end

    # sites/<slug>, or nil when there is no theme.
    def root(theme = slug)
      return nil if theme.blank?

      Rails.root.join(DIRECTORY, validate!(theme))
    end

    # sites/<slug>/views -- the directory that shadows app/views.
    def views_path(theme = slug)
      root(theme)&.join(VIEWS_SUBDIRECTORY)
    end

    # Is there anything to install? A configured theme whose directory is absent
    # is tolerated (see the initializer), so callers have to ask.
    def views_available?(theme = slug)
      path = views_path(theme)
      !path.nil? && path.directory?
    end

    # Locale files to append to I18n.load_path. Dir sorts its results, so a
    # theme with several files loads them in the same order everywhere.
    def locale_files(theme = slug)
      base = root(theme)
      return [] if base.nil?

      Dir[base.join(LOCALES_GLOB)]
    end

    # Prepends the theme's view directory to each target class, and returns the
    # view paths each one had before, so a caller can put them back.
    #
    # prepend_view_path builds a fresh resolver every time, so the theme's
    # templates can never be served out of the app/views resolver's cache and
    # nothing needs invalidating -- in production or in the test environment,
    # where cache_template_loading follows cache_classes and is on.
    def install!(theme, on: default_targets)
      path = views_path(theme)
      raise ArgumentError, 'install! needs a theme slug' if path.nil?

      targets = Array(on)
      # Snapshot every target before mutating any of them, so a failure part way
      # through still hands the caller everything it needs to unwind.
      previous = targets.index_with(&:view_paths)
      targets.each { |target| target.prepend_view_path(path.to_s) }
      previous
    end

    # Undoes #install!, given exactly what it returned.
    def restore!(previous_view_paths)
      previous_view_paths.each { |target, paths| target.view_paths = paths }
    end

    # Runs the block with the theme installed -- views and locales both -- and
    # restores the process to its previous state afterwards. For specs: the
    # suite runs generic, and a handful of examples opt in to prove a real
    # theme's templates still render.
    #
    # This mutates process-global state (the view paths of two framework classes
    # and I18n.load_path), so it is NOT safe under parallel specs in the same
    # process: a sibling example rendering a view inside the block would get the
    # theme's copy. RSpec here runs single-threaded, which is what makes it safe.
    def with_theme(theme, on: default_targets)
      previous_view_paths = install!(theme, on: on)
      previous_load_path = install_locales!(theme)
      yield
    ensure
      restore!(previous_view_paths) if previous_view_paths
      restore_locales!(previous_load_path) if previous_load_path
    end

    # ActionController::Base and ActionMailer::Base are the two roots whose view
    # paths every page and every email inherits. Resolved lazily: naming them at
    # load time would force both frameworks to load before their on_load hooks
    # have run.
    def default_targets
      [ActionController::Base, ActionMailer::Base]
    end

    private

    def install_locales!(theme)
      files = locale_files(theme)
      return nil if files.empty?

      previous = I18n.load_path.dup
      I18n.load_path.concat(files)
      I18n.reload!
      previous
    end

    def restore_locales!(previous)
      I18n.load_path.replace(previous)
      I18n.reload!
    end

    def default_server_config
      Rails.configuration.x.server_config
    end

    # server_config is a string-keyed Hash from YAML in the app, but specs pass
    # plain symbol-keyed hashes.
    def lookup(config, key)
      return nil unless config.respond_to?(:[])

      value = config[key]
      value.nil? ? config[key.to_sym] : value
    end
  end
end
