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
    Production.accessible_by(current_ability).where(current_user.is_theater_user? ? "1=1" : "(status != 'Inactive' and exists (select * from theaters where theaters.status != 'Inactive' and theaters.id = productions.theater_id)) or productions.theater_id = 1").order('name')
  end

  def production_image_id(production)
    "\#showimage_#{production.id}"
  end

  def production_image_style(production)
    raw "<style>
    #{production_image_id(production)} {
            background: #{production.decorate.promo_url(Production:MEDIUM)} no-repeat center center;
            display:block;
            overflow:hidden;
            white-space:nowrap;
            text-indent:100%;
            height: 375px;
          }
    </style>"
  end
end