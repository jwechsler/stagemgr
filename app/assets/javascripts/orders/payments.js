
function show_proper_payment_form() {
  jQuery(function($) {
    $('#payment_forms').children('div').each(function() {
      $(this).hide();
    });
    switch ($('#ticket_order_payment_type').val()) {
      case 'Credit Card':
        $('#credit_card_payment_form').show();
        break;
      case 'Cash':
        $('#cash_payment_form').show();
        break;
      case 'FlexPass':
        $('#flex_pass_payment_form').show();
        break;
      case 'Membership':
        $('#membership_payment_form').show();
        break;
    }
  });
}

