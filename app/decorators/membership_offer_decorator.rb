class MembershipOfferDecorator < ApplicationDecorator
  delegate_all

  def name
    h.link_to(object.name, [:admin, object])
  end

  def on_sale?
    show_as_checkmark if object.on_sale?
  end

  def dt_actions
    order_action = object.active? ? h.link_to('Create Order', [:new, :admin, object, :order], class: 'tiny button') : '(Inactive)'
    edit_action = h.link_to('Edit', [:edit, :admin, object], class: 'tiny button')
    h.safe_join([order_action, edit_action], ' ')
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
