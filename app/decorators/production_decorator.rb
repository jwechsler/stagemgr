class ProductionDecorator < ApplicationDecorator
  delegate_all

  def dt_actions
    actions = []
    if h.current_user.can? :destroy, Production
      actions << if object.performances.count == 0
                   h.link_to('Destroy', [:admin, object.theater, object], confirm: 'Are you sure?', method: :delete,
                                                                          class: 'alert tiny button')
                 else
                   h.link_to('Destroy', '#', method: :get, class: 'disabled alert tiny button')
                 end
    end
    if h.current_user.can? :edit, Production
      actions << h.link_to('Edit', [:edit, :admin, object.theater, object], class: 'tiny button')
    end
    if h.current_user.can? :read, TicketClass
      actions << h.link_to('Ticket Classes', [:admin, object.theater, object, :ticket_classes], class: 'tiny button')
    end
    h.safe_join(actions, ' ')
  end

  def name
    h.link_to(object.name, [:admin, object.theater, object]) +
      (object.custom_label.blank? ? '' : h.raw("<br/><span class=\"label\">#{object.custom_label.titlecase}</span>"))
  end

  def status
    h.raw("<span class=\"label\">#{production.status}</span>")
  end

  def theater_link
    h.link_to(object.theater.name, [:admin, object.theater])
  end

  def promo_url(*dimensions)
    make_image_url(object.promo, dimensions)
  end

  def promo(*dimensions)
    make_image_tag(object.promo, dimensions)
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
