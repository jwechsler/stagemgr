source 'http://rubygems.org'

gem 'rails', '3.1.0'

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

gem "whenever", :require=>false
gem "formtastic", '~> 1.2.3'
gem "databasedotcom", '~> 1.1.1'
gem "formatize"
gem "validation_reflection"
gem "declarative_authorization"
gem "activemerchant", :git => 'https://github.com/florianguenther/active_merchant'
gem "mysql2"
gem "authlogic"
gem "acts_as_audited",        "2.0.0.rc7"
gem "will_paginate",          '3.0.pre2'
gem "my_emma"
gem "paperclip",               "~> 2.3"
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
  gem 'bond',                 '0.2.1'
  gem 'g',                    '1.4.0'
  gem 'capistrano',           '2.5.18'
  gem 'capistrano-ext',       '1.2.1'
end

group :test do
  gem 'sqlite3-ruby'
  gem 'cucumber'
  gem 'cucumber-rails'
  gem 'webrat',             '>=0.5.0'
  gem 'rspec',              '>=1.3.0'
  gem 'rspec-rails',        '>=1.3.2'
  gem 'test-unit',          '>=2.0.7'
  gem 'flexmock',           '0.8.6'
  gem 'rcov',               '>=0.9.8'
  gem 'shoulda-context'
  gem "factory_girl",       '1.3.2'
end

group :production do
  gem 'newrelic_rpm'
  gem 'exception_notification', :require=>'exception_notifier'
end

group :cucumber do
  gem 'sqlite3-ruby'
  gem 'capybara',           '0.4.0'
  gem 'database_cleaner'
  gem 'cucumber'
  gem 'cucumber-rails'
  gem 'webrat',             '>=0.5.0'
  gem 'rspec',              '>=1.3.0'
  gem 'rspec-rails',        '>=1.3.2'
  gem 'test-unit',          '>=2.0.7'
  gem 'rcov',               '>=0.9.8'
  gem "factory_girl",       '1.3.2'
  gem 'launchy'
end

gem "mocha", :group => :test
