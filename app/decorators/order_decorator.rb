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
    h.raw("<span class=\"label #{order_status_severity_class}\">#{order.status}</span>")
  end

  def address
    if object.address.nil?
      "???"
    else
      display = ""
      display += "<br/>(h/u #{object.hold_under})" unless (object.hold_under.blank? || object.hold_under.eql?(object.address.full_name) || object.display_code.eql?("DONATION"))
      h.link_to(object.address.full_name, [:admin, object.address]) + h.raw(display)
    end
  end

  def seats
    object.seats.map { |s| s.seat.location }.sort.join(', ')
  end

  def description
    result = ""
    if (object.is_a? FlexPassOrder) && (!object.flex_pass.nil?) then
      result = h.raw("<span class=\"label warning\">Expired</span> ") if !order.flex_pass.active?
    end
    result += order.description
  end

  private
  def order_status_severity_class
    case object.status
    when Order::FULFILLED
      "success"
    when Order::REFUNDED
      "alert"
    when Order::CANCELED
      "alert"
    when Order::HOLD
      "alert"
    when Order::PROCESSING
      "alert"
    else
      "secondary"
    end
  end


end

