class PerformanceDecorator < ApplicationDecorator
  delegate_all

  def dt_actions
    actions = []
    
    if h.current_user.can? :update, Performance then
      actions << h.link_to('Edit', [:edit,:admin, object.production.theater, object.production, object], :id=>"edit_#{object.performance_code.gsub(' ','_')}", class: 'tiny button')
    end
    if h.current_user.can? :create, Performance then
      actions << h.link_to('Duplicate', [:duplicate, :admin, object.production.theater, object.production, object], :id=>"duplicate_#{object.performance_code.gsub(' ','_')}", class: 'tiny button' )
    end
    if h.current_user.can? :delete, Performance then
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
    h.raw("<span class=\"label\">#{object.status}</span>" + (object.withhold_from_public? ? " <span class=\"label alert\">Blocked</span>" : ""))
  end

  def order_link(display_text = nil, link_classes = [], link_style = '')
    display_text ||= object.performance_time.to_s(:hour_min).lstrip
    result = ''
    if (object.performance_at + object.production.running_time.minutes < Time.now) || object.sold_out? || object.withhold_from_public?
      result << "<del>#{display_text}</del><br/>"
      if performance.sold_out? || performance.withhold_from_public?
        result << "<font size=\"-2\">Sold out!</font>"
      end
    else
      if (object.near_capacity? || object.happening_soon?) && !object.order_url_override.blank?
        result << "#{display_text}<br/>"
        if performance.near_capacity?
          result << "<font size=\"-2\">#{object.number_of_seats_left.eql?(1) ? '1 ticket' : 'Limited seats'} remaining. Contact box office</font>"
        else
          result << "<font size=\"-2\">Door sales only</font>"
        end
      else
        result << h.link_to( h.raw(display_text), (object.order_url_override.blank? ?  h.new_order_path(object) : object.order_url_override), class: link_classes.join(' '), style: link_style )
      end
    end
    h.raw(result)
  end

end
