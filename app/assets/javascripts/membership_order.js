//= require orders/front_end_common
//= require orders/payments
//= require_self

order_type = 'membership_order';

jQuery(document).ready(function() {
  show_proper_payment_form(order_type);
  setup_gift_form(order_type);
});

jQuery(function($) {
  //clear bindings so we don't add multiple event handlers
  payment_type_input = $('#membership_order_payment_type');
  payment_type_input.unbind();
  payment_type_input.change(function() {
    show_proper_payment_form();
  });
});
