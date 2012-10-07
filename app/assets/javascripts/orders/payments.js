

function show_proper_payment_form(order_type) {
  jQuery(document).ready(function($) {
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
      case 'FlexPass':
        $('#flex_pass_payment_form').show();
        break;
      case 'Membership':
        $('#membership_payment_form').show();
        break;
    }
  });
}


function setup_payment_form(order_type) {
  jQuery(document).ready(function($) {
    $("#"+ order_type+"_payment_type").change(function() {
      show_proper_payment_form(order_type);
    });
  });
}