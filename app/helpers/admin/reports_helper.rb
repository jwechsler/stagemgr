module Admin::ReportsHelper

  def select_week_of
    c_week = 16.weeks.ago.to_date
    s = Array.new
    until c_week > Date.today
      s << WeekSelect.new(c_week)
      c_week += 1.week
    end
    s.sort!{ |d1,d2| d2.value <=> d1.value }
  end

end
