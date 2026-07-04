class TicketClassDecorator < ApplicationDecorator
  delegate_all
  def dt_actions
    actions = []
    if h.current_user.can? :update,
                           TicketClass
      actions << h.link_to('Edit', [:edit, :admin, object.production.theater, object.production, object],
                           class: 'button tiny')
    end
    if h.current_user.can? :destroy,
                           TicketClass
      actions << h.link_to('Destroy', [:admin, object.production.theater, object.production, object],
                           confirm: 'Are you sure?', method: :delete, class: 'button alert tiny')
    end
    h.safe_join(actions, ' ')
  end

  def ticket_price
    h.raw("<span class=\"text-right\">#{number_to_currency object.ticket_price}</span>")
  end

  def ticketing_fee
    h.raw "<span class=\"text-right\">#{number_to_currency ticket_class.ticketing_fee}</span>"
  end

  def web_visible?
    object.web_visible? ? show_as_checkmark : ''
  end

  def ticket_type
    h.raw(make_label(object.ticket_type) +
      (object.minutes_before_show.blank? ? '' : make_label(" #{object.minutes_before_show} minutes before")) +
      auto_attach_indicator)
  end

  private

  def make_label(value)
    "<span class=\"label info\">#{value}</span>"
  end

  def auto_attach_indicator
    return '' unless object.auto_attach?

    ' <span class="auto-attach-indicator" title="Added automatically to orders">＋</span>'
  end
end
