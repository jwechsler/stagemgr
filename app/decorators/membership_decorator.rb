class MembershipDecorator < ApplicationDecorator
  delegate_all

  DATE_FORMAT = '%m/%d/%Y'.freeze

  def member_code
    h.link_to(object.member_code, [:admin, object])
  end

  # The offer name followed by its type labels (Production, Timed, Prepaid),
  # styled as on the membership offers list. safe_join escapes the name.
  def offer_label
    offer = object.membership_offer
    h.safe_join([offer.name, offer.decorate.membership_type_display], ' ')
  end

  def member_name
    object.address&.full_name
  end

  # Membership start: the Stripe subscription start when present, else the
  # record's member_since — same COALESCE the usage reports use.
  def start_date_display
    (object.start_date || object.member_since)&.strftime(DATE_FORMAT)
  end

  # ended_at is authoritative for closed memberships. A one-time membership
  # still running shows its last valid day (expires_on); an active membership
  # scheduled to cancel at period end shows its final billing date.
  def membership_end
    return object.ended_at.strftime(DATE_FORMAT) if object.ended_at.present?
    return expires_display if object.one_time?
    return unless object.cancel_at_period_end? && object.next_billing_date.present?

    h.safe_join([object.next_billing_date.strftime(DATE_FORMAT),
                 h.ui_label('Cancel pending', variant: :warning, class: 'tiny')], ' ')
  end

  def expires_display
    h.safe_join([object.expires_on.strftime(DATE_FORMAT), h.ui_label('Expires', variant: :info, class: 'tiny')], ' ')
  end

  def dt_actions
    actions = []
    actions << h.link_to('Edit', [:edit, :admin, object], class: 'tiny button') if h.current_user.can?(:update, object)
    h.safe_join(actions, ' ')
  end
end
