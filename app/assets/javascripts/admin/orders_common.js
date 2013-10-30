//= require utility
//= require orders/payments
//= require admin/address_utility
//= require admin/ticket_order_utility
//= require admin/ticket_orders/CardReader
//= require_self

var order_type;

jQuery(document).ready(function($) {

  $('#admin_ticket_order_form').each(function() {

    order_type = 'ticket_order'

    setup_ticket_autocompletes('ticket_order');

    setup_address_autocompletes('ticket_order');

    setup_line_item_row_control('ticket_order');

    setup_payment_form('ticket_order');

  });

  $('#admin_membership_order_form').each(function() {

    order_type = 'membership_order'

    setup_address_autocompletes(order_type);

    setup_payment_form(order_type);

    setup_gift_form(order_type)

  });

  $('#admin_flex_pass_order_form').each(function() {

    order_type = 'flex_pass_order'

    setup_address_autocompletes(order_type);

    setup_payment_form(order_type);

    setup_address_autocompletes(order_type);

  });

//  $('#admin_exchange_ticket_order_form').each(function() {
//
//    var order_type = 'ticket_order'
//
//    setup_ticket_autocompletes('ticket_order');
//
//    setup_address_autocompletes(order_type);
//
//    setup_payment_form(order_type);
//
//
//  });

  $('input.ticket_count,input.price_override').on('change',function() {
      recalculate_row_total(order_type,$(event.target).parents('tr'))
    });

  $('#update_note_control').hide();

  $('#update_note').click(function() {
      $('#note_control').hide();
      $('#update_note_control').show('slow');
      return false;
    });


});

