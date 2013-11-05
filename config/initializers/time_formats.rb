Date::DATE_FORMATS[:numeric_month_and_day] = "%m/%d"
Time::DATE_FORMATS.merge!(
:standard_time=>"%I:%M%P",
:short_date_and_time=>"%m/%d/%y %I:%M%P",
:paypal=>PayPalControllerHelper::PAYPAL_DATETIME_FORMAT
)
