//= require orders/payments
//= require_this

function show_gift_form() {
  e = $("#gift_information");
  v = $(".third_party_checkbox input.boolean").each(function() {
    if ($(this).is(':checked')) {
      e.removeClass("hide");
    } else {
      e.addClass('hide');
    }
  })
}

function setup_gift_form() {
    $(".third_party_checkbox input").change(function() {
      show_gift_form();
    });
    show_gift_form();
}

jQuery(document).ready(function($) {
  setup_payment_form();
  setup_gift_form();
});

