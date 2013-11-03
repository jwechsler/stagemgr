//= require orders/payments
//= require_this

function show_gift_form() {
  e = $("#gift_information")
  v = $(".third_party_checkboxes").each(function() {
    if ($(this).is(':checked')) {
      e.show();
    } else {
      e.hide();
    }
  })
}

function setup_gift_form() {
    $(".third_party_checkboxes").change(function() {
      show_gift_form();
    });
    show_gift_form();
}

jQuery(document).ready(function($) {

  setup_payment_form();
  setup_gift_form();

});

