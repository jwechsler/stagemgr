Date::DATE_FORMATS[:numeric_month_and_day] = "%m/%d"
Date::DATE_FORMATS[:long_with_day_of_week] = "%A, %B %d %Y"
Time::DATE_FORMATS.merge!(
:standard_time=>"%I:%M%P",
:short_date_and_time=>"%m/%d/%y %I:%M%P",
:paypal=>PayPalControllerHelper::PAYPAL_DATETIME_FORMAT
)
