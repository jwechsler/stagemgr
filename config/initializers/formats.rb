ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
  :hour_min => "%I:%M %p"
)

ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
  :show_time => "%l:%M %p"
)

ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS.merge!(
  :dd_mm_yyyy => "%m/%d/%Y"
)
ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS.merge!(
:show_date => "%A, %B %e"
)


