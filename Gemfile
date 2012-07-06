source 'http://rubygems.org'

gem 'rails', '3.1.5'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'sqlite3-ruby', :require => 'sqlite3'


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

gem "RedCloth", "4.2.9"
gem "whenever", :require=>false
gem "formtastic"
gem "databasedotcom"
gem "formatize"
gem "validation_reflection"
gem "declarative_authorization"
gem "activemerchant", :git => 'https://github.com/florianguenther/active_merchant'
gem "mysql2"
gem "authlogic"
gem "acts_as_audited", "~> 2.1.0"
gem "will_paginate",          '~> 3.0.3'
gem "my_emma", :git=> "https://github.com/hashrocket/my_emma.git"
gem "paperclip",               "~> 3.0.4"
gem "htmldiff"
gem "StreetAddress",          "~> 1.0.1"
gem "fastercsv"
gem "money"
gem "gemcutter"
gem "postmark-rails"
gem "namecase", "~> 1.1.0"
gem "name_parse", "~> 0.0.5"

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
end

group :test do
  gem 'sqlite3-ruby'
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
  gem "factory_girl_rails", "~> 3.0"
end

group :production do
  gem 'newrelic_rpm'
  gem 'exception_notification', :require=>'exception_notifier'
end

group :cucumber do
  gem 'sqlite3-ruby'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'cucumber'
  gem 'cucumber-rails'
  gem 'webrat',             '>=0.5.0'
  gem 'launchy'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'test-unit',          '>=2.0.7'
  gem 'simplecov'
  gem "factory_girl_rails", "~> 3.0"
  gem "rbx-require-relative"
end

gem "mocha", :group => :test
