require 'fileutils'

namespace :config do
  desc 'Generate local config/*.yml files from their checked-in *.yml.example templates (does not overwrite existing files)'
  # Deliberately NOT dependent on :environment. Some of the generated files
  # (notably database.yml) are required before Rails can boot, so this task
  # must run without loading the application. It mirrors the bootstrap step in
  # .claude/hooks/session-start.sh so a fresh install can be configured the
  # same way from the command line: `rake config:setup`.
  #
  # Rails/RakeEnvironment is disabled here precisely because this task must NOT
  # load the app: it generates database.yml, which Rails needs before it boots.
  task :setup do # rubocop:disable Rails/RakeEnvironment
    examples = Dir.glob(File.expand_path('../../config/*.yml.example', __dir__))

    if examples.empty?
      puts 'config:setup: no config/*.yml.example templates found.'
      next
    end

    created = []
    skipped = []

    examples.sort.each do |example|
      target = example.sub(/\.example\z/, '')
      if File.exist?(target)
        skipped << target
      else
        FileUtils.cp(example, target)
        created << target
      end
    end

    created.each { |path| puts "  created  #{rel(path)}" }
    skipped.each { |path| puts "  exists   #{rel(path)} (left unchanged)" }

    puts "config:setup: #{created.size} created, #{skipped.size} already present."
    puts 'Review the generated files and fill in environment-specific values before starting the app.' if created.any?
  end

  # Render a path relative to the project root for tidy output.
  def rel(path)
    root = File.expand_path('../..', __dir__)
    path.start_with?("#{root}/") ? path.sub("#{root}/", '') : path
  end
end
