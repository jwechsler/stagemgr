source 'http://rubygems.org'
# source 'https://rails-assets.org'

gem 'rails', '~> 6.1'

gem 'webpacker'
gem 'bootsnap'
gem 'activerecord-session_store'
gem "i18n-js"

gem "redcarpet" # Markdown

gem "simple_form"
gem 'simple-form-datepicker'
# gem "databasedotcom"
# gem 'restforce', '~> 2.5.3'
# gem "validation_reflection"
gem "cancancan"
gem "activeresource"  
gem "activemerchant"
gem "stripe"
gem "stripe_event"
gem "scrypt"
gem "authlogic"
gem "audited"
# gem "psych", '3.3.3'
# gem "will_paginate"
#gem 'safe_attributes', :require=> 'safe_attributes/base'  # Used to support legacy rails 2 schema names for TrgExport model
gem "my_emma",  "~>0.1.3", :git=>"https://github.com/jwechsler/my_emma.git"
# or develop against "~/dev/my_emma"
# gem "my_emma", :path=>"~/dev/my_emma"
# gem 'terrapin'
# gem "htmldiff"
gem "StreetAddress" # parses street addresses for matching checks
gem "i18n"          # i18n exposes for dates and money gem
gem "money"
gem "money-rails"
gem "monetize"
# gem "gemcutter"
gem 'font-awesome-rails'
gem "cocoon"
gem "bigdecimal" # , '1.4.4'
gem "haml"
gem "postmark-rails"
gem "validates_formatting_of"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "jquery-datatables"
gem 'ajax-datatables-rails', '> 1.0.0'
gem 'rails-jquery-autocomplete' # :git=>"https://github.com/jwechsler/rails3-jquery-autocomplete.git" #:path=>'/Users/jeremyw/dev/rails3-jquery-autocomplete'

gem 'sass'
gem 'sass-rails'
gem 'coffee-rails'
gem 'uglifier'
# Add Foundation Here
gem 'bourbon'
gem 'foundation-rails'
gem 'foundation-icons-sass-rails'
gem 'autoprefixer-rails'

gem 'draper'
gem 'yajl-ruby', require: 'yajl'
gem 'jquery-timepicker-rails'
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
gem 'resque-lock-timeout'

gem 'config', :git=>'https://github.com/railsconfig/config.git'
gem 'responders'
gem 'decent_exposure'
gem 'activestorage-validator' # validates blobs for activestorage

gem 'dotenv-rails', groups: [:development, :test]
gem 'image_processing'
# gem 'mini_magick'
gem 'ruby-vips'

gem 'whiny_validation'

#reports
gem 'chartkick'

group :development do
  gem 'listen'
  gem 'wirble'
  gem 'what_methods'
  gem 'map_by_method'
  gem 'bond'
#  gem 'g'
#  gem 'terminal-notifier'
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
  gem 'factory_bot_rails'
  
end

group :test,:cucumber do
  gem 'capybara'
  gem 'puma'
  # gem 'poltergeist'
  gem 'selenium-webdriver'
  gem 'cucumber-rails', '2.5.1', :require=>false
  gem 'simplecov'
  gem 'database_cleaner-active_record'
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
  gem 'exception_notification' #, '< 4.5' # rails 5.0
  gem 'mysql2'
end

group :development,:production do
  gem 'resque-web', :require=>'resque_web'
end


group :cucumber do
  gem 'launchy'
  gem "rbx-require-relative"
end

# assets
  
