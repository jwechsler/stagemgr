require 'capybara/cucumber'
require 'capybara/session'

Capybara.default_driver = :rack_test # non-JS eg rake-test