function show_proper_payment_form(order_type) {
  jQuery(function($) {
    $('#payment_forms').children('div').each(function() {
      $(this).hide();
    });
    switch ($('#' + order_type + '_payment_type').val()) {
      case 'Credit Card':
        $('#credit_card_payment_form').show();
        break;
      case 'Cash':
        $('#cash_payment_form').show();
        break;
    }
  });
}

jQuery(document).ready(function($) {
  show_proper_payment_form("flex_pass_order");
  $('#flex_pass_order_payment_type').change(function() {
    show_proper_payment_form("flex_pass_order");
  });
});
