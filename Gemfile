source 'http://rubygems.org'

gem 'rails', '3.1.10'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'


# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug'

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

gem "redcarpet"
gem "whenever", :require=>false
gem "formtastic"
gem "databasedotcom"
gem "formatize"
gem "validation_reflection"
gem "declarative_authorization"
gem "activemerchant"
gem "mysql2"
gem "authlogic"
gem "acts_as_audited", "~> 2.1.0"
gem "will_paginate",          '~> 3.0.3'
gem "my_emma",  "~>0.0.4", :git=>"https://github.com/jwechsler/my_emma.git"
# or develop against "~/dev/my_emma"
#gem "my_emma", :path=>"~/dev/my_emma"
gem "paperclip",               "~> 3.1.2"
gem "htmldiff"
gem "StreetAddress",          "~> 1.0.1"
gem "money"
gem "gemcutter"
gem "postmark-rails"
gem "namecase", "~> 1.1.0"
#gem "name_parse", "~> 0.0.5"
gem "people"
gem "jquery-rails", '~> 2.1.0'
gem "ri_cal", :git=>"https://github.com/ctide/ri_cal.git"
gem 'resque', :require => 'resque/server'
gem 'resque-web', :require=>'resque_web'
gem 'resque-scheduler', :require=>'resque_scheduler'
gem 'resque-retry'

#gem "rails3-jquery-autocomplete", :path=>"~/dev/rails3-jquery-autocomplete", :branch=>"v2"


group :development do
  gem 'wirble',               '0.1.3'
  gem "nifty-generators"
  gem 'what_methods',         '1.0.1'
  gem 'map_by_method',        '0.8.3'
  gem 'bond',                 '0.4.2'
  gem 'g',                    '~> 1.6.0'
  gem 'mongrel',              '1.2.0.pre2'
  gem 'capistrano',           '~> 2.12.0'
  gem 'capistrano-ext',       '1.2.1'
  gem 'pry'
  gem 'httplog', :require=>false
  gem 'debugger'
  gem 'single_test'
  gem 'ruby_parser'  # for declarative authorization eager loading for resque tasks
end

group :development,:test,:cucumber do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
end

group :test do
  gem 'sqlite3'
  gem 'capybara'
  gem 'cucumber-rails', :require=>false
  gem 'database_cleaner'
  gem 'webrat',             '>=0.5.0'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'test-unit',          '>=2.0.7'
  gem 'flexmock',           '0.8.6'
  gem 'simplecov'
  gem 'shoulda-context'
end

group :production do
  gem 'newrelic_rpm'
  gem 'exception_notification', :require=>'exception_notifier'
end

group :cucumber do
  gem 'sqlite3'
  gem 'capybara'
  gem 'database_cleaner'
  gem "factory_girl_rails"
  gem 'cucumber-rails'
  gem 'cucumber'
  gem 'launchy'
  gem 'rspec-rails'
  gem 'test-unit',          '>=2.0.7'
  gem 'simplecov'

  gem "rbx-require-relative"
end

group :assets do
  gem 'sass-rails', "~> 3.1.0"
  gem 'coffee-rails', '~> 3.1.0'
  gem 'uglifier'
end

gem "mocha", :group => :test
