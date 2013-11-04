

function show_proper_payment_form() {
  $('#payment_forms').children('div').each(function() {
    $(this).hide();
  });
  switch ($('.payment_type_choice option:selected').text()) {
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
}


function setup_payment_form() {

  show_proper_payment_form();

  jQuery(document).ready(function($) {
    $(".payment_type_choice").change(function() {
      show_proper_payment_form();
    });
  });
}

