//= require orders/front_end_common
//= require orders/payments
//= require_self

var order_type = 'ticket_order'

setup_payment_form(order_type);

function show_special_request_form(order_type) {
  e = ${"#" + order_type + "_special_request"}
  e.fadeToggle();
  if !e.is(':visible') {
    e.val('')
  }
}

 jQuery(document).ready(function($) {
    $("#"+ order_type+"_special_request").change(function() {
      show_special_request_form(order_type);
    });
  });