module ProductionsHelper
  def soft_date(date)

    case date.mday
            when 1..10
              "early #{date.strftime('%B')}"
            when 11..20
              "mid-#{date.strftime('%B')}"
            when 21..31
              "late #{date.strftime('%B')}"
    end

  end

end