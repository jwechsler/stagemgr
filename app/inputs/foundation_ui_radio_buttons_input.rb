class FoundationUiRadioButtonsInput < SimpleForm::Inputs::CollectionRadioButtonsInput
  # Creates a radio button set for use with Foundation UI

  def input(_wrapper_options)
    label_method, value_method = detect_collection_methods
    # The caller names the checked value (:checked); it was hard-coded to 1,
    # so every re-shown order form switched to Credit Card.
    iopts = {
      checked: options[:checked],
      collection_wrapper_tag: 'div'
    }
    @builder.send(
      'collection_radio_buttons',
      attribute_name,
      collection,
      value_method,
      label_method,
      iopts,
      input_html_options,
      &collection_block_for_nested_boolean_style
    )
  end # method

  protected

  def build_nested_boolean_style_item_tag(collection_builder)
    tag = ''
    tag << (collection_builder.radio_button + collection_builder.label)
    tag.html_safe
  end # method
end # class
