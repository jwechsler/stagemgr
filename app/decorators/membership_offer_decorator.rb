class MembershipOfferDecorator < ApplicationDecorator
  delegate_all

  def name
    h.link_to(object.name, [:admin, object])
  end

  def on_sale?
    return h.ui_label('Inactive', variant: :alert, class: 'tiny') unless object.active?

    show_as_checkmark if object.on_sale?
  end

  # Renders the "Create Order" button, enabled only for active, non-timed
  # offers. Shared by the offers datatable and the offer show page so the
  # enable/disable criteria live in exactly one place.
  def create_order_button(css_class: 'tiny button')
    if object.active? && !object.timed?
      h.link_to('Create Order', [:new, :admin, object, :order], class: css_class)
    else
      h.content_tag(:span, 'Create Order', class: "#{css_class} disabled", 'aria-disabled': true)
    end
  end

  # Renders the "Issue Pass" button for staff-issued timed (library) passes.
  def issue_pass_button(css_class: 'tiny button')
    h.link_to('Issue Pass', h.new_admin_membership_path(membership_offer_id: object.id), class: css_class)
  end

  # The primary sales action for an offer: timed passes are issued, everything
  # else is sold through the normal order flow. Used by the offer show page,
  # which surfaces only one of the two.
  def sales_action_button(css_class: 'tiny button')
    object.timed? ? issue_pass_button(css_class: css_class) : create_order_button(css_class: css_class)
  end

  def dt_actions
    actions = []
    # Membership offers are administrator-managed; box office staff only view
    # them and create orders.
    actions << h.link_to('Edit', [:edit, :admin, object], class: 'tiny button') if h.current_user.can?(:update, object)
    actions << create_order_button
    actions << issue_pass_button if object.timed?
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
