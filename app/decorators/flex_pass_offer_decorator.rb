class FlexPassOfferDecorator < ApplicationDecorator
  delegate_all

  # What each payout field means; shown as hints on the offer form and beside
  # the figures on the show page.
  PAYOUT_HINTS = {
    flat_payout: 'Per pass sold. Owed to the producer whether or not the pass is used; not recovered at expiry.',
    spiff: 'Per pass sold. Added to the amount due to the facility.',
    facility_fee: "Per pass sold. The facility's share, kept at sale; not recovered at expiry."
  }.freeze

  def name
    h.link_to(object.name, [:admin, object])
  end

  def price
    h.number_to_currency(object.price)
  end

  def facility_fee
    h.number_to_currency(object.facility_fee || 0)
  end

  def spiff
    h.number_to_currency(object.spiff || 0)
  end

  def flat_payout
    h.number_to_currency(object.flat_payout || 0)
  end

  def on_sale_to_public?
    show_as_checkmark if object.on_sale_to_public?
  end

  def restrictions
    labels = []
    labels << h.ui_label('Inactive', variant: :alert, class: 'tiny') unless object.active?
    labels << h.ui_label(restriction_text, variant: :info, class: 'tiny') if restriction_text.present?
    labels << h.ui_label("Max #{object.maximum_uses_per_production}/production", variant: :info, class: 'tiny') if object.maximum_uses_per_production.to_i.positive?
    labels << h.ui_label("Max #{object.maximum_uses_per_performance}/performance", variant: :info, class: 'tiny') if object.maximum_uses_per_performance.to_i.positive?
    h.safe_join(labels, ' ')
  end

  def dt_actions
    actions = []
    if h.current_user.can? :update, FlexPassOffer
      actions << h.link_to('Edit', [:edit, :admin, object], class: 'tiny button')
    end

    if h.current_user.can? :destroy, FlexPassOffer
      actions << h.link_to('Destroy', [:admin, object], method: :delete, confirm: 'Are you sure?',
                                                        class: 'tiny alert button')
    end

    # Inactive offers render in their own datatable tab, so a disabled
    # Create Order button would be redundant — omit it entirely.
    if h.current_user.can?(:create, FlexPassOrder) && flex_pass_offer.active?
      actions << h.link_to('Create Order', [:new, :admin, object, :order], class: 'tiny button')
    end

    h.safe_join(actions, ' ')
  end

  def restriction_text
    if object.theater.blank?
      ''
    elsif object.exclude_theater
      "All but #{object.theater.name}"
    else
      "Only #{object.theater.name}"
    end
  end

  # --- Show page ---

  def theater_scope_text
    restriction_text.presence || 'Any theater'
  end

  def status_labels
    labels = [active_label, sale_label]
    labels << h.ui_label('Festival pass', variant: :info) if object.festival
    labels << h.ui_label('Autofulfill', variant: :info) if object.autofulfill?
    h.safe_join(labels, ' ')
  end

  # Per-production / per-performance caps; nil or 0 means uncapped.
  def uses_cap_text(limit)
    limit.to_i.positive? ? h.pluralize(limit, 'ticket') : 'No limit'
  end

  def expiration_text
    "#{h.pluralize(object.months_till_expiration.to_i, 'month')} after purchase"
  end

  def code_format_example
    "#{object.code_prefix}#{'X' * FlexPass::CODE_SUFFIX_LENGTH}"
  end

  def recoverable_at_expiry
    h.number_to_currency(object.recoverable_at_expiry)
  end

  def public_purchase_url
    h.new_flex_pass_offer_order_url(object)
  end

  # Full-size Edit / Create Order buttons; Destroy stays on the index.
  def show_actions
    actions = []
    if h.current_user.can? :update, FlexPassOffer
      actions << h.link_to('Edit', h.edit_admin_flex_pass_offer_path(object), class: 'button')
    end
    if h.current_user.can?(:create, FlexPassOrder) && object.active?
      actions << h.link_to('Create Order', [:new, :admin, object, :order], class: 'button')
    end
    h.safe_join(actions, ' ')
  end

  private

  def active_label
    object.active? ? h.ui_label('Active', variant: :success) : h.ui_label('Inactive', variant: :alert)
  end

  def sale_label
    if object.on_sale_to_public?
      h.ui_label('On sale to public', variant: :primary)
    else
      h.ui_label('Box office only', variant: :secondary)
    end
  end
end
