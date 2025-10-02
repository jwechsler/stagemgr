
function show_payment_form(payment_type) {
  $('#payment_forms').children('div').each(function() {
    $(this).hide();
  });
  switch (payment_type) {
    case "1":
      $('#credit_card_payment_form').show();
      break;
    case "3":
      $('#flex_pass_payment_form').show();
      break;
    case "5":
      $('#membership_payment_form').show();
      console.log("find membership")
      break;
    case "6":
      $('#check_payment_form').show();
      break;
  }
}

function show_proper_admin_payment_form() {
  show_payment_form($("[name*='payment_type_id']").val());
}

function show_proper_payment_form() {
  show_payment_form($("[name*='payment_type_id']:checked").val());
}

function setup_payment_form() {
  show_proper_payment_form();
  jQuery(document).ready(function($) {
    $(".payment_type_choice input").change(function() {
      show_proper_payment_form();
    });
  });
}

