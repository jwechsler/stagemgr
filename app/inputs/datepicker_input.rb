# `as: :datepicker` (orders/_gift_recipient): a native <input type="date">,
# which submits %Y-%m-%d and gets the browser's own picker.
#
# Until 2026-10 this rendered a text field plus a hidden copy of the same
# param for a jQuery UI altField. Nothing on the public pages ever started
# that picker, so the hidden copy stayed blank and, coming last, overrode the
# typed date: every gift date was dropped and gifts started on purchase.
class DatepickerInput < SimpleForm::Inputs::StringInput
  def input_html_options
    value = object.send(attribute_name)
    super.merge(value: value&.strftime('%Y-%m-%d'), min: Date.current.strftime('%Y-%m-%d'))
  end

  def input_html_classes
    super.push('datepicker')
  end

  def input(_wrapper_options = nil)
    @builder.date_field(attribute_name, input_html_options)
  end
end
