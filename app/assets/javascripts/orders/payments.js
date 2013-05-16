

function show_proper_payment_form(order_type) {
  jQuery(document).ready(function($) {
    $('#payment_forms').children('div').each(function() {
      $(this).hide();
    });
    switch ($('#' + order_type + '_payment_type_id option:selected').text()) {
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
      case 'Check':
        $('#check_payment_form').show();
        break;
    }
  });
}


function setup_payment_form(order_type) {

  show_proper_payment_form(order_type);

  jQuery(document).ready(function($) {
    $("#"+ order_type+"_payment_type_id").change(function() {
      show_proper_payment_form(order_type);
    });
  });
}

function show_gift_form(order_type) {
  e = $("#gift_information")
  v = $("#" + order_type + "_gift")
  if (v.is(':checked')) {
    e.show();
  } else {
    e.hide();
  }
}

function setup_gift_form(order_type) {
 jQuery(document).ready(function($) {
    $("#" + order_type + "_gift").change(function() {
      show_gift_form(order_type);
    });
    show_gift_form(order_type);
  });
}