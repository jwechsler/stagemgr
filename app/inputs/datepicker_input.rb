# `as: :datepicker` (orders/_gift_recipient). Adopted from the
# simple-form-datepicker gem (0.1.3), which provided only this class and
# predates Simple Form's wrapper_options signature. Renders the date as
# %Y-%m-%d with a hidden "<attribute>-alt" copy for jQuery UI's altField.
class DatepickerInput < SimpleForm::Inputs::StringInput
  def input_html_options
    value = object.send(attribute_name)
    super.merge(value: value&.strftime('%Y-%m-%d'), data: { behaviour: 'datepicker' })
  end

  def input_html_classes
    super.push('datepicker')
  end

  def input(_wrapper_options = nil)
    @builder.text_field(attribute_name, input_html_options) +
      @builder.hidden_field(attribute_name, value: input_html_options[:value], class: "#{attribute_name}-alt")
  end
end
