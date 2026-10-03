class OrderDecorator < ApplicationDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def id
    h.link_to(object.id, [:admin, object])
  end

  def total_paid
    h.number_to_currency(object.total_paid)
  end

  def total
    h.number_to_currency(object.total)
  end

  def status
    h.safe_join([status_label, review_label].compact, ' ')
  end

  def address
    if object.address.nil?
      '???'
    else
      display = ''
      unless object.hold_under.blank? || object.hold_under.eql?(object.address.full_name) || object.display_code.eql?('DONATION')
        display += "<br/>(h/u #{object.hold_under})"
      end
      h.link_to(object.address.full_name, [:admin, object.address]) + h.raw(display)
    end
  end

  def seats
    object.seats.map { |s| s.seat.location }.sort.join(', ') unless object.seats.empty?
  end

  def description
    result = ''
    if (object.is_a? FlexPassOrder) && !object.flex_pass.nil? && !order.flex_pass.active?
      result = h.raw('<span class="label warning">Expired</span> ')
    end
    result + order.description
  end

  # Admin orders listing: the description followed by the date the order was
  # placed, e.g. "Muses on 09/20 14:30 (2 COMP), placed 09/19". The placed date
  # is created_at, the same value OrderReport and RevenueCalculator treat as the
  # order date.
  def description_with_placed_date
    description + ", placed #{object.created_at.to_date.to_formatted_s(:numeric_month_and_day)}"
  end

  private

  def status_label
    if (object.is_a? MembershipOrder) && !object.membership.nil?
      if object.membership.active?
        label(order.status, order_status_severity_class)
      elsif object.membership.pending?
        label(object.membership.status, 'secondary')
      else
        label(object.membership.status, 'alert')
      end
    else
      label(order.status, order_status_severity_class)
    end
  end

  # Reads only the order's own columns, so the listing adds no query for it.
  def review_label
    return unless object.needs_review?

    h.content_tag(:span, 'Review', class: 'label alert review-flag', title: object.review_reason)
  end

  def label(text, severity)
    h.content_tag(:span, text, class: "label #{severity}")
  end

  def order_status_severity_class
    case object.status
    when Order::FULFILLED
      'success'
    when Order::REFUNDED
      'alert'
    when Order::CANCELED
      'alert'
    when Order::HOLD
      'alert'
    when Order::PROCESSING
      'alert'
    else
      'secondary'
    end
  end
end
