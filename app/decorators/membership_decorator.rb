class MembershipDecorator < ApplicationDecorator
  delegate_all

  DATE_FORMAT = '%m/%d/%Y'.freeze

  def member_code
    h.link_to(object.member_code, [:admin, object])
  end

  def offer_label
    "#{object.membership_offer.name} (#{object.membership_offer.membership_type})"
  end

  def member_name
    object.address&.full_name
  end

  # Membership start: the Stripe subscription start when present, else the
  # record's member_since — same COALESCE the usage reports use.
  def start_date_display
    (object.start_date || object.member_since)&.strftime(DATE_FORMAT)
  end

  # ended_at is authoritative for closed memberships; an active membership
  # scheduled to cancel at period end shows its final billing date.
  def membership_end
    return object.ended_at.strftime(DATE_FORMAT) if object.ended_at.present?
    return unless object.cancel_at_period_end? && object.next_billing_date.present?

    h.safe_join([object.next_billing_date.strftime(DATE_FORMAT),
                 h.ui_label('Cancel pending', variant: :warning, class: 'tiny')], ' ')
  end

  def dt_actions
    actions = []
    actions << h.link_to('Edit', [:edit, :admin, object], class: 'tiny button') if h.current_user.can?(:update, object)
    h.safe_join(actions, ' ')
  end
end
