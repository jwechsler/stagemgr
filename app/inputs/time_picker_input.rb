class TimePickerInput < SimpleForm::Inputs::Base
  def input(_wrapper_options)
    @builder.text_field(attribute_name, input_html_options)
  end
end
