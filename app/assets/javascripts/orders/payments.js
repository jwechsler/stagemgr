

function show_proper_payment_form() {
  $('#payment_forms').children('div').each(function() {
    $(this).hide();
  });
  switch ($("[name*='payment_type_id']:checked").val()) {
    case "1":
      $('#credit_card_payment_form').show();
      break;
    case "3":
      $('#flex_pass_payment_form').show();
      break;
    case "5":
      $('#membership_payment_form').show();
      break;
    case "6":
      $('#check_payment_form').show();
      break;
  }
}


function setup_payment_form() {

  show_proper_payment_form();
  jQuery(document).ready(function($) {
    $(".payment_type_choice input").change(function() {
      show_proper_payment_form();
    });
  });
}

