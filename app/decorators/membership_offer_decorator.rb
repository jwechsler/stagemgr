class MembershipOfferDecorator < ApplicationDecorator
  delegate_all

  def name
    h.link_to(object.name, [:admin, object])
  end

  def on_sale?
    show_as_checkmark if object.on_sale?
  end

  def dt_actions
    object.active? ? h.link_to("Create Order", [:new, :admin, object, :order], class: 'tiny button') : '(Inactive)'
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
