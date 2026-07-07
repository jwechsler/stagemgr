class FlexPassOfferDecorator < ApplicationDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end
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

    if h.current_user.can? :create, FlexPassOrder
      actions << if flex_pass_offer.active?
                   h.link_to('Create Order', [:new, :admin, object, :order], class: 'tiny button')
                 else
                   h.link_to('Create Order', '#', class: 'tiny button disabled')
                 end
    end

    h.safe_join(actions, ' ')
  end

  private

  def restriction_text
    if object.theater.blank?
      ''
    elsif object.exclude_theater
      "All but #{object.theater.name}"
    else
      "Only #{object.theater.name}"
    end
  end
end
