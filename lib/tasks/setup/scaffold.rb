# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require_relative 'env_file'

module Setup
  # Turns a fresh clone into a runnable checkout: copies the tracked *.example
  # templates into the gitignored files the app actually reads, seeds a site
  # theme directory, and fills in a generated SECRET_KEY_BASE.
  #
  # Nothing here boots Rails — config/database.yml is one of the files it
  # generates, so the app cannot be loaded yet. Everything is addressed relative
  # to an injected +root:+ so the whole class is testable against a tmpdir.
  #
  # Every operation is idempotent and refuses to overwrite an existing file.
  class Scaffold
    # Matches SiteTheme's slug validation; also blocks path traversal.
    SLUG_FORMAT = /\A[a-z0-9_-]+\z/
    EXAMPLE_SITE = 'example'

    # Raised for conditions the operator has to fix (a bad slug, a missing
    # template directory). Rake tasks turn these into `abort`.
    class Error < StandardError; end

    def initialize(root:, out: $stdout)
      @root = File.expand_path(root.to_s)
      @out = out
    end

    # config/*.yml.example -> config/*.yml, .env.example -> .env.
    # Returns { created: [relative paths], skipped: [relative paths] }.
    def config
      results = { created: [], skipped: [] }

      templates.each do |template|
        target = template.sub(/\.example\z/, '')
        if File.exist?(target)
          results[:skipped] << rel(target)
        else
          FileUtils.cp(template, target)
          results[:created] << rel(target)
        end
      end

      report_config(results)
      results
    end

    # sites/example -> sites/<slug>, then point server.yml at it.
    # Returns { site: <symbol>, server_yml: <symbol> }.
    def site(slug)
      validate_slug!(slug)
      source = path('sites', EXAMPLE_SITE)
      unless File.directory?(source)
        raise Error, "#{rel(source)} is missing from this checkout — there is no template to copy. " \
                     'Create the directory (see sites/README.md) or copy an existing theme by hand.'
      end

      result = { site: copy_site(source, slug), server_yml: register_site_theme(slug) }
      report_site(slug)
      result
    end

    # Fills a blank or missing SECRET_KEY_BASE in .env. Returns :generated or
    # :present. Never replaces a value that is already there.
    def secret_key_base
      env = EnvFile.new(path('.env'))
      if env['SECRET_KEY_BASE']
        say "  exists   SECRET_KEY_BASE already set in #{rel(env.path)} (left unchanged)"
        return :present
      end

      say "  created  #{rel(env.path)}" unless env.exist?
      env['SECRET_KEY_BASE'] = SecureRandom.hex(64)
      say "  wrote    SECRET_KEY_BASE in #{rel(env.path)}"
      :generated
    end

    private

    attr_reader :root

    def templates
      list = Dir.glob(path('config', '*.yml.example'))
      dotenv = path('.env.example')
      list << dotenv if File.exist?(dotenv)
      list
    end

    def report_config(results)
      results[:created].each { |file| say "  created  #{file}" }
      results[:skipped].each { |file| say "  exists   #{file} (left unchanged)" }
      say "setup:config: #{results[:created].size} created, #{results[:skipped].size} already present."
      return if results[:created].empty?

      say 'Review the generated files and fill in deployment-specific values before starting the app.'
    end

    # A new theme is empty on purpose -- a blank override would render an empty
    # section rather than the generic one -- so say how to put something in it.
    def report_site(slug)
      say ''
      say 'Next steps: a theme overrides views by shadowing them. Copy the generic file, then edit the copy:'
      say ''
      say '    cp app/views/order_mailer/_transportation_instructions.html.haml \\'
      say "       sites/#{slug}/views/order_mailer/"
      say ''
      say 'An override replaces the generic file completely and stops receiving later fixes to it, so'
      say "override the smallest file that has the words you want to change. sites/#{slug}/README.md lists"
      say 'the usual candidates; sites/README.md explains what belongs in a theme and what belongs in the'
      say '`theater:` block of config/server.yml instead.'
    end

    def copy_site(source, slug)
      destination = path('sites', slug)
      if File.exist?(destination)
        say "  exists   #{rel(destination)} (left unchanged)"
        return :present
      end

      FileUtils.cp_r(source, destination)
      say "  created  #{rel(destination)} (copied from #{rel(source)})"
      :created
    end

    # Inserts `site_theme: <slug>` under the `all:` block of config/server.yml.
    # A line edit rather than a YAML round-trip, so the file's comments and key
    # order survive untouched.
    def register_site_theme(slug)
      server_yml = path('config', 'server.yml')
      unless File.exist?(server_yml)
        say "  skipped  #{rel(server_yml)} not present — run `rake setup:config` first, " \
            "then add `site_theme: #{slug}` under `all:`"
        return :no_server_yml
      end

      lines = File.readlines(server_yml)
      if lines.any? { |line| line.match?(/\A\s*site_theme\s*:/) }
        say "  exists   site_theme already set in #{rel(server_yml)} (left unchanged)"
        return :already_set
      end

      index = lines.index { |line| line.match?(/\Aall:\s*(#.*)?\z/) }
      if index.nil?
        say "  skipped  no `all:` block in #{rel(server_yml)} — add `site_theme: #{slug}` by hand"
        return :no_all_block
      end

      lines.insert(index + 1, "  site_theme: #{slug}\n")
      File.write(server_yml, lines.join)
      say "  wrote    site_theme: #{slug} in #{rel(server_yml)}"
      :inserted
    end

    def validate_slug!(slug)
      return if slug.to_s.match?(SLUG_FORMAT)

      raise Error, "invalid site slug #{slug.inspect} — use lowercase letters, digits, hyphens and underscores."
    end

    def path(*parts)
      File.join(root, *parts)
    end

    def rel(absolute)
      absolute.start_with?("#{root}/") ? absolute.sub("#{root}/", '') : absolute
    end

    def say(message)
      @out.puts(message)
    end
  end
end
