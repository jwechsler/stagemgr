source 'https://rubygems.org'
# source 'https://rails-assets.org'

gem 'rails', '~> 6.1'

gem 'activerecord-session_store'
gem 'bootsnap'
gem 'i18n-js'
gem 'webpacker'

gem 'redcarpet', '~> 3.6' # Markdown

gem 'simple_form', '~> 5.1'
gem 'simple-form-datepicker'
# gem "databasedotcom"
# gem 'restforce', '~> 2.5.3'
# gem "validation_reflection"
gem 'activemerchant'
gem 'activeresource'
gem 'audited'
gem 'authlogic'
gem 'cancancan', '~> 3.3'
gem 'scrypt'
gem 'stripe'
gem 'stripe_event'
# gem "psych", '3.3.3'
# gem "will_paginate"
# gem 'safe_attributes', :require=> 'safe_attributes/base'  # Used to support legacy rails 2 schema names for TrgExport model
gem 'my_emma', git: 'https://github.com/jwechsler/my_emma.git'
# or develop against "~/dev/my_emma"
# gem "my_emma", :path=>"~/dev/my_emma"
# gem 'terrapin'
# gem "htmldiff"
gem 'i18n'          # i18n exposes for dates and money gem
gem 'monetize'
gem 'money'
gem 'money-rails'
gem 'StreetAddress' # parses street addresses for matching checks
# Removed base64 gem as it's part of Ruby 3.2.2 standard library
# gem "gemcutter"
gem 'ajax-datatables-rails', '> 1.0.0'
gem 'cocoon'
gem 'font-awesome-rails'
gem 'haml'
gem 'jquery-datatables'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'postmark-rails'
gem 'rails-jquery-autocomplete' # :git=>"https://github.com/jwechsler/rails3-jquery-autocomplete.git" #:path=>'/Users/jeremyw/dev/rails3-jquery-autocomplete'
gem 'validates_formatting_of'

gem 'coffee-rails'
gem 'dartsass-sprockets'
# The production box runs macOS 13; sass-embedded 1.98.0 bumped the bundled
# Dart runtime's minimum to macOS 14 (its compiler process dies at launch,
# aborting assets:precompile). Lift the cap once that machine is on 14+.
gem 'sass-embedded', '>= 1.80', '< 1.98'
gem 'uglifier'
# Foundation 6.9 via npm (foundation-sites in package.json)
gem 'autoprefixer-rails'

gem 'draper'
gem 'jquery-timepicker-rails'
gem 'yajl-ruby', require: 'yajl'
# gem 'jqgrid-rails3', :git=>"https://github.com/davebaldwin/jqgrid-rails3.git"
# gem "name_parse", "~> 0.0.5"
gem 'namae'
gem 'rack-attack', require: 'rack/attack'
gem 'redis', '~> 4.8.0' # Updated for better Ruby 3.2.2 compatibility

gem 'ri_cal', git: 'https://github.com/ctide/ri_cal.git'

# scheduling and crons
gem 'redis-namespace'
gem 'resque', '~> 2.6.0', require: 'resque/server'
gem 'resque-lock-timeout'
gem 'resque-retry' # , :git=>"https://github.com/jwechsler/resque-retry.git"
gem 'resque-scheduler'
gem 'whenever', require: false

gem 'activestorage-validator', '0.4.0' # validates blobs for activestorage
gem 'config', git: 'https://github.com/railsconfig/config.git'
gem 'decent_exposure'
gem 'responders'

gem 'dotenv-rails', groups: %i[development test]
gem 'image_processing'
# gem 'mini_magick'
gem 'ruby-vips'

gem 'whiny_validation'

# reports
gem 'chartkick'

group :development do
  gem 'bond'
  gem 'listen'
  gem 'map_by_method'
  gem 'what_methods'
  gem 'wirble'
  #  gem 'g'
  #  gem 'terminal-notifier'
  #  gem 'mongrel'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'haml-rails'
  gem 'http_logger'
  gem 'pry'
  gem 'pry-rails'
  gem 'single_test'

  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false

  # gem 'ruby_parser'  # for declarative authorization eager loading for resque tasks
end

# was also :cucumber, but I don't know why...
group :test do
  gem 'byebug'
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'puma'
  gem 'rails-controller-testing'
  gem 'sqlite3', '~> 1.6.9'
  # gem 'poltergeist'
  gem 'cucumber-rails', '2.5.1', require: false
  gem 'database_cleaner-active_record'
  gem 'selenium-webdriver', '~> 4.15' # Latest stable version
  gem 'simplecov'
  gem 'stripe-ruby-mock'
end

group :test do
  gem 'syntax'

  gem 'fakeredis', require: 'fakeredis/rspec'
  gem 'flexmock'
  gem 'mocha', require: false
  gem 'rspec-rails', '< 6.0'
end

group :production, :test do
  #  gem 'newrelic_rpm'
  gem 'exception_notification' # , '< 4.5' # rails 5.0
  gem 'mysql2'
end

group :development, :production do
  gem 'resque-web', require: 'resque_web'
end

group :cucumber do
  gem 'launchy'
  gem 'rbx-require-relative'
end

# assets

gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby ruby]

gem 'ffi', '1.17.0'
gem 'nio4r', '~> 2.5.9'
