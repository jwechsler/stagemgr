function show_proper_payment_form() {
  jQuery(function($) {
    $('#payment_forms').children('div').each(function() {
      $(this).hide();
    });
    switch ($('#membership_order_payment_type').val()) {
      case 'Credit Card':
        $('#credit_card_payment_form').show();
        break;
      case 'Cash':
        $('#cash_payment_form').show();
        break;
      case 'FlexPass':
        $('#flex_pass_payment_form').show();
        break;
    }
  });
}

jQuery(document).ready(function() {
  show_proper_payment_form();
});

jQuery(function($) {
  //clear bindings so we don't add multiple event handlers
  payment_type_input = $('#membership_order_payment_type');
  payment_type_input.unbind();
  payment_type_input.change(function() {
    show_proper_payment_form();
  });
});
