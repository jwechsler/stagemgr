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

  def productions_visible_to_operations
    Production.with_permissions_to(:read).where(current_user.is_theater_user? ? "1=1" : "(status != 'Inactive' and exists (select * from theaters where theaters.status != 'Inactive' and theaters.id = productions.theater_id)) or productions.theater_id = 1").order('name')
  end
end