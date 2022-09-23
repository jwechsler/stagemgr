class SeatMapDecorator < ApplicationDecorator
  delegate_all

  def label
    h.link_to(object.label,[:admin, object.venue, object])
  end

  def base_image_map(*dimensions)
    make_image_tag(object.base_image_map,dimensions)
  end

  def base_image_map_url(*dimensions)
    make_image_url(dimensions)
  end

  def dt_actions
    actions = []
    actions << h.link_to("Edit", [:edit,:admin, object.venue, object], class: 'tiny button') if h.current_user.can?(:edit, SeatMap)
    actions << ("<li>" + h.link_to('Destroy', [:admin, object.venue, object], :confirm => 'Are you sure?', :method => :delete, :class=>'tiny alert button') + "</li>") if h.current_user.can?(:destroy, SeatMap)
    h.raw("<ul class=\"button-group\"><li>#{actions.join('</li><li>')}</li></ul>")
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
