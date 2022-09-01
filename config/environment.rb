# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Stagemgr::Application.initialize!

Time::DATE_FORMATS.merge!(
  :default => '%m/%d/%Y',
  :date_time12  => "%m/%d/%Y %I:%M%p",
  :date_time24  => "%m/%d/%Y %H:%M",
  :hour_min => "%l:%M%p",
  :show_date => "%A, %B %e"
)

Date::DATE_FORMATS.merge!(
  :show_date => "%A, %B %e"
)

# Currency gem settings

Money.locale_backend = :i18n

# example (using default localization from rails-i18n):
I18n.locale = :en
Money.rounding_mode=BigDecimal::ROUND_HALF_UP
Money.default_currency=Money::Currency.new("USD")

require 'htmldiff'
require 'monetize/core_extensions'
