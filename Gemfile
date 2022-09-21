source 'http://rubygems.org'
# source 'https://rails-assets.org'

gem 'rails', '~> 5.2.8.1'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'


# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# Bundle the extra gems:
# gem 'bj'
# gem 'nokogiri'
# gem 'sqlite3-ruby', :require => 'sqlite3'
# gem 'aws-s3', :require => 'aws/s3'

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
# group :development, :test do
#   gem 'webrat'
# end

gem 'bootsnap'
gem 'activerecord-session_store'
# Markdown
gem "redcarpet"

gem "simple_form"
gem "databasedotcom"
gem 'restforce', '~> 2.5.3'
# gem "validation_reflection"
gem "cancancan"
gem "activeresource"
gem "activemerchant"
gem "stripe"
gem "stripe_event"
#gem "braintree"
#gem "braintree-rails"
gem "scrypt"
gem "authlogic", '~> 4.4'
gem "audited"
gem "psych", '3.3.3'
gem "will_paginate"
gem 'safe_attributes', :require=> 'safe_attributes/base'  # Used to support legacy rails 2 schema names for TrgExport model
gem "my_emma",  "~>0.1.3", :git=>"https://github.com/jwechsler/my_emma.git"
# or develop against "~/dev/my_emma"
#gem "my_emma", :path=>"~/dev/my_emma"
gem 'terrapin'
gem "kt-paperclip"
gem "htmldiff"
gem "StreetAddress"
gem "i18n"
gem "money"
gem "money-rails"
gem "monetize"
gem "gemcutter"
gem 'font-awesome-rails'
gem "dynamic_form"
gem "cocoon"
gem "bigdecimal", '1.4.4'
gem "nested_form_fields"
gem "haml"
gem "postmark-rails"
gem "validates_formatting_of"
# gem "namecase"
gem "jquery-rails"
gem "jquery-ui-rails"
# gem 'autonumeric-rails'
gem "jquery-datatables"
gem 'ajax-datatables-rails', '> 1.0.0'
gem 'draper'
gem 'yajl-ruby', require: 'yajl'
gem 'foundation-datetimepicker-rails'
# gem 'jqgrid-rails3', :git=>"https://github.com/davebaldwin/jqgrid-rails3.git"
#gem "name_parse", "~> 0.0.5"
gem "people"
gem "redis", "< 4.8.0"

gem "ri_cal", :git=>"https://github.com/ctide/ri_cal.git"

# scheduling and crons
gem "whenever", :require=>false
gem 'resque', :require => 'resque/server'
gem 'resque-scheduler'
gem 'resque-retry'  #, :git=>"https://github.com/jwechsler/resque-retry.git"

gem 'rails-jquery-autocomplete' # :git=>"https://github.com/jwechsler/rails3-jquery-autocomplete.git" #:path=>'/Users/jeremyw/dev/rails3-jquery-autocomplete'
gem 'config', :git=>'https://github.com/railsconfig/config.git'
gem 'responders'
gem 'mini_magick'
gem 'decent_exposure'
gem 'activestorage-validator'
#

group :development do
  gem 'listen'
  gem 'wirble'
#  gem "nifty-generators"
  gem 'what_methods'
  gem 'map_by_method'
  gem 'bond'
  gem 'g'
  gem 'terminal-notifier'
#  gem 'mongrel'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'pry-rails'
  gem 'pry'
  gem 'http_logger'
  gem 'rb-readline'
  gem "haml-rails"
  gem 'single_test'

  # gem 'ruby_parser'  # for declarative authorization eager loading for resque tasks
end

group :development,:test,:cucumber do
  gem 'sqlite3', '~> 1.4.0'
  gem 'rails-controller-testing'
  gem 'byebug'
end

group :test,:cucumber do
  gem 'capybara'
  gem 'puma'
  # gem 'poltergeist'
  gem 'selenium-webdriver'
  gem 'cucumber-rails', :require=>false
  gem 'simplecov'
  gem 'factory_bot_rails'
  gem 'database_cleaner'
  gem 'stripe-ruby-mock'
end

group :test do
  gem 'syntax'

  gem 'rspec-rails', '< 6.0'
  gem "mocha", :require => false
  gem 'flexmock'
  gem 'fakeredis', :require => "fakeredis/rspec"
end

group :production do
#  gem 'newrelic_rpm'
  gem 'exception_notification', '< 4.5' # rails 5.0
  gem 'mysql2', "~> 0.4.10"
end

group :development,:production do
  gem 'resque-web', :require=>'resque_web'
end


group :cucumber do
  gem 'cucumber'

  gem 'launchy'
  gem "rbx-require-relative"
end

# assets
  gem 'sass'
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
  # Add Foundation Here
  gem 'bourbon'
  gem 'foundation-rails'
  gem 'foundation-icons-sass-rails'
  gem 'autoprefixer-rails'

