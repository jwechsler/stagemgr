class MembershipOfferDecorator < ApplicationDecorator
  delegate_all

  def name
    h.link_to(object.name, [:admin, object])
  end

  def on_sale?
    return h.ui_label('Inactive', variant: :alert, class: 'tiny') unless object.active?

    show_as_checkmark if object.on_sale?
  end

  def dt_actions
    order_action =
      if object.active?
        h.link_to('Create Order', [:new, :admin, object, :order], class: 'tiny button')
      else
        h.content_tag(:span, 'Create Order', class: 'tiny button disabled', 'aria-disabled': true)
      end
    actions = []
    # Membership offers are administrator-managed; box office staff only view
    # them and create orders.
    actions << h.link_to('Edit', [:edit, :admin, object], class: 'tiny button') if h.current_user.can?(:update, object)
    actions << order_action
    actions << h.link_to('Usage', h.membership_offer_usage_admin_reports_path(object), class: 'tiny button')
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
