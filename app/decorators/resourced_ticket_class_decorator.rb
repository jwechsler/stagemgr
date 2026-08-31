class ResourcedTicketClassDecorator < ApplicationDecorator
  delegate_all

  def class_code
    h.link_to(object.class_code, [:admin, object])
  end

  def venue_names
    object.venues.order(:ordinal_sort).pluck(:name).join(', ')
  end

  def ticket_price
    h.content_tag(:span, h.number_to_currency(object.ticket_price), class: 'text-right')
  end

  def changeover_minutes
    "#{object.changeover_minutes} min"
  end

  def dt_actions
    actions = []
    if h.current_user.can? :update, object
      actions << h.link_to('Edit', [:edit, :admin, object], class: 'tiny button')
    end
    if h.current_user.can? :destroy, object
      actions << h.link_to('Destroy', [:admin, object], confirm: 'Are you sure?', method: :delete,
                                                        class: 'tiny alert button')
    end
    h.safe_join(actions, ' ')
  end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
end
