module DateUtils
  class << self
    def months_between(date1 = Time.now, date2 = Time.now)
      date1 ||= Time.now
      date2 ||= Time.now

      if date1 > date2

        recent_date = date1.to_date
        past_date = date2.to_date

      else

        recent_date = date2.to_date
        past_date = date1.to_date

      end

      (recent_date.month - past_date.month) + (12 * (recent_date.year - past_date.year))
    end
  end
end
