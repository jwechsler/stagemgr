ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
# ActiveSupport 6.1 reopens stdlib Logger without requiring it. Newer httparty
# no longer eager-loads logger as a side effect, so require it explicitly
# before bootsnap caches any load paths.
require 'logger'
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
