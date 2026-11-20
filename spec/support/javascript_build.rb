# frozen_string_literal: true

# Builds the esbuild bundle (app/assets/builds/seat_map_editor.js) before a
# test run that needs it, so `bundle exec rspec` and `bundle exec cucumber`
# work without a separate `yarn build` step. Sprockets cannot serve, and
# javascript_include_tag raises for, a bundle that was never built.
#
# Loaded by spec/rails_helper.rb and features/support/javascript_build.rb. It
# runs `yarn build` once, and only when the output is missing or older than any
# of its inputs; an up-to-date build costs one directory scan.
module JavascriptBuild
  OUTPUT = Rails.root.join('app/assets/builds/seat_map_editor.js')
  INPUT_GLOBS = %w[app/javascript/**/*.js package.json yarn.lock].freeze
  BUILD_COMMAND = 'yarn build'

  module_function

  def ensure_built!
    return unless stale?

    warn "==> #{OUTPUT.relative_path_from(Rails.root)} is missing or stale; running `#{BUILD_COMMAND}`"
    return if system(BUILD_COMMAND, chdir: Rails.root.to_s)

    raise "`#{BUILD_COMMAND}` failed; run `yarn install` and then `#{BUILD_COMMAND}` by hand to see why"
  end

  def stale?
    return true unless OUTPUT.exist?

    built_at = OUTPUT.mtime
    INPUT_GLOBS.flat_map { |glob| Rails.root.glob(glob) }.any? { |input| File.mtime(input) > built_at }
  end
end

JavascriptBuild.ensure_built!
