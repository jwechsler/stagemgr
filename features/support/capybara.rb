require 'capybara/cucumber'
require 'capybara/session'

Capybara.default_driver = :rack_test # non-JS eg rake-test
Capybara.javascript_driver = :webkit
Capybara.server = :webrick
Capybara::Webkit.configure do |config|
  # Enable debug mode. Prints a log of everything the driver is doing.
  config.debug = false

  config.allow_unknown_urls
end
