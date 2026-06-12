class SpecialOfferDecorator < ApplicationDecorator
  delegate_all

  def code
    h.link_to(object.code, h.edit_admin_special_offer_path(object))
  end

  def description
    object.to_s
  end

  def dt_actions
    h.link_to('Edit', [:edit, :admin, object], :class => 'tiny button')
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
