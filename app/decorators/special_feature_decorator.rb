class SpecialFeatureDecorator < ApplicationDecorator
  delegate_all

  def short_name
    h.link_to(object.short_name, [:admin, object])
  end

  def description
    h.raw($MARKDOWN.render(object.description))
  end

  def status
    h.raw("<span class=\"label\">#{object.status}</span>")
  end

  def dt_actions
    (if h.current_user.can?(:edit,
                            object)
       h.link_to('Edit', [:edit, :admin, object], id: "edit_#{object.short_name.downcase.gsub(' ', '_')}",
                                                  class: 'tiny button') + ' '
     else
       ''
     end) +
      (if h.current_user.can?(:destroy,
                              object)
         h.link_to('Destroy', [:admin, object], confirm: 'Are you sure?', method: :delete,
                                                class: 'tiny alert button')
       else
         ''
       end)
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
