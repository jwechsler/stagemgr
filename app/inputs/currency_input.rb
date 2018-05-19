class CurrencyInput < SimpleForm::Inputs::Base

  def input(wrapper_options)
    input_html_classes.unshift("string currency")
    input_html_options[:type] = :number

    template.content_tag(:span, "$", class: "add-on") +
      @builder.text_field(attribute_name, merge_wrapper_options(input_html_options, wrapper_options)
  end
end