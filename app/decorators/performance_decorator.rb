class PerformanceDecorator < ApplicationDecorator
  delegate_all

  def dt_actions
    actions = []

    if h.current_user.can? :update, Performance
      actions << h.link_to('Edit', [:edit, :admin, object.production.theater, object.production, object],
                           id: "edit_#{object.performance_code.gsub(' ', '_')}", class: 'tiny button')
    end
    if h.current_user.can? :create, Performance
      actions << h.link_to('Duplicate', [:duplicate, :admin, object.production.theater, object.production, object],
                           id: "duplicate_#{object.performance_code.gsub(' ', '_')}", class: 'tiny button')
    end
    if h.current_user.can?(:release_held_seats, Performance) && object.production.has_reserved_seating?
      actions << h.link_to('Release Held Seats', h.release_held_seats_admin_theater_production_performance_path(object.production.theater, object.production, object),
                           method: :post,
                           data: { confirm: 'Are you sure you want to release all held seats for this performance?' },
                           class: 'tiny button alert',
                           id: "release_seats_#{object.performance_code.gsub(' ', '_')}")
    end
    if h.current_user.can?(:email_attendees, Performance)
      actions << h.link_to('Email Attendees', '#',
                           class: 'tiny button secondary email-attendees-btn',
                           data: {
                             performance_id: object.id,
                             performance_code: object.performance_code,
                             theater_id: object.production.theater.id,
                             production_id: object.production.id,
                             production_name: object.production.name,
                             performance_date: object.performance_date.strftime('%m/%d')
                           },
                           id: "email_attendees_#{object.performance_code.gsub(' ', '_')}")
    end
    if h.current_user.can? :delete, Performance
      # actions << h.link_to('Delete', [:destroy, :admin, object], :id=>"delete_#{object.performance_code.gsub(' ','_')}", :confirm=> "Are you sure?" , class: 'tiny button alert' )
    end
    h.safe_join(actions, ' ')
  end

  def performance_time
    object.performance_time.to_s(:hour_min)
  end

  def performance_code
    h.link_to(object.performance_code, [:admin, object.production.theater, object.production, object])
  end

  def status
    h.raw("<span class=\"label\">#{object.status}</span>" + (object.withhold_from_public? ? ' <span class="label alert">Blocked</span>' : ''))
  end

  def order_link(display_text = nil, link_classes = [], link_style = '', suppress_display_if_unavailable = false)
    display_text ||= object.performance_time.to_s(:hour_min).lstrip
    result = ''
    if object.order_url_override.present?
      result << h.link_to(h.raw(display_text), object.order_url_override, class: link_classes.join(' '),
                                                                          style: link_style)
      return h.raw(result)
    end
    if (object.performance_at + object.production.running_time.minutes < Time.now) || object.calendar_sold_out? || object.withhold_from_public?
      result << "<del>#{display_text}</del><br/>"
      result << '<font size="-2">Sold out!</font>' if object.calendar_sold_out? || object.withhold_from_public?
    elsif object.calendar_near_capacity? || object.happening_soon?
      result << "#{display_text}<br/>" unless suppress_display_if_unavailable
      if object.calendar_near_capacity?
        result << "<font size=\"-2\">#{object.calendar_seats_left.eql?(1) ? '1 ticket' : 'Limited seats'} remaining. Call box office</font>"
      else
        result << '<font size="-2">Tickets available at door</font>'
      end
    else
      result << h.link_to(h.raw(display_text), h.new_order_path(object), class: link_classes.join(' '),
                                                                         style: link_style)
    end
    h.raw(result)
  end
end
