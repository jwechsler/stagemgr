ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.merge!(
  :hour_min => "%I:%M %p"
)
ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS.merge!(
  :dd_mm_yyyy => "%m/%d/%Y"
)
