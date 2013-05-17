//= require utility
//= require orders/payments
//= require admin/address_utility
//= require admin/ticket_orders/CardReader
//= require_self


jQuery(document).ready(function($) {
  $('#update_note_control').hide();

  $('#update_note').click(function() {
      $('#note_control').hide();
      $('#update_note_control').show('slow');
      return false;
    });
});

