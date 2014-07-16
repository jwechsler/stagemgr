source 'http://rubygems.org'
source 'https://rails-assets.org'

gem 'rails', '3.2.16'

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
gem "formtastic", "~> 2.3.0.rc2"
gem "simple_form"
gem "databasedotcom"
gem "formatize"
# gem "validation_reflection"
gem "declarative_authorization"
gem "activemerchant"
gem "mysql2"
gem "authlogic", "~> 3.1.0"
gem "acts_as_audited", "~> 2.1.0"
gem "will_paginate",          '~> 3.0.3'
gem 'safe_attributes', :require=> 'safe_attributes/base'  # Used to support legacy rails 2 schema names for TrgExport model
gem "my_emma",  "~>0.0.4", :git=>"https://github.com/jwechsler/my_emma.git"
# or develop against "~/dev/my_emma"
#gem "my_emma", :path=>"~/dev/my_emma"
gem 'cocaine', '0.3.2'
gem "paperclip",               "~> 3.1.2"
gem "htmldiff"
gem "StreetAddress",          "~> 1.0.1"
gem "money", "6.1.0.beta1"
gem "monetize"
gem "gemcutter"
gem 'font-awesome-rails'
gem "dynamic_form"
gem "cocoon"
gem "haml"
gem "postmark-rails"
gem "namecase", "~> 1.1.0"
gem 'jquery-datatables-rails', git: 'git://github.com/rweng/jquery-datatables-rails.git', branch: 'master'
# gem 'autonumeric-rails'
gem 'ajax-datatables-rails'
# gem 'jqgrid-rails3', :git=>"https://github.com/davebaldwin/jqgrid-rails3.git"
#gem "name_parse", "~> 0.0.5"
gem "people"
gem "jquery-rails", '~> 2.1.0'
gem "ri_cal", :git=>"https://github.com/ctide/ri_cal.git"
gem 'resque', :require => 'resque/server'
gem 'resque-scheduler', :require=>'resque_scheduler'
gem 'resque-retry', :git=>"https://github.com/jwechsler/resque-retry.git"
gem 'foundation-datetimepicker-rails'

gem 'rails3-jquery-autocomplete', :git=>"https://github.com/jwechsler/rails3-jquery-autocomplete.git"


group :development do
  gem 'wirble',               '0.1.3'
  gem "nifty-generators"
  gem 'what_methods',         '1.0.1'
  gem 'map_by_method',        '0.8.3'
  gem 'bond'
  gem 'g',                    '~> 1.6.0'
  gem 'mongrel',              '1.2.0.pre2'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv', '~> 2.0'
  gem 'pry'
  gem 'rb-readline'
  gem "haml-rails"
  gem 'httplog', :require=>false
  gem 'debugger'
  gem 'single_test'
  gem 'ruby_parser'  # for declarative authorization eager loading for resque tasks
end

group :development,:test,:cucumber do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'database_cleaner'
end


group :test,:cucumber do
  gem 'capybara'
  gem 'capybara-webkit'
  gem 'sqlite3'
  gem 'cucumber-rails', :require=>false
  gem 'test-unit'
  gem 'simplecov'
end

group :test do
  gem 'syntax'
  gem 'webrat'
  gem 'rspec'
  gem "mocha", "~> 0.12.0", :require => false
  gem 'flexmock',           '0.8.6'
  gem 'shoulda-context'
  gem 'fakeredis', :require => "fakeredis/rspec"
end

group :production do
#  gem 'newrelic_rpm'
  gem 'exception_notification'
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
group :assets do
  gem 'sass', '3.2.13'
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
  # Add Foundation Here
  gem 'compass-rails' # you need this or you get an err
  gem 'foundation-rails'
  gem 'foundation-icons-sass-rails'
end

