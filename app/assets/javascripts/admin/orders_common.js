//= require utility
//= require orders/payments
//= require admin/address_utility
/* //= require admin/ticket_order_utility */
//= require admin/ticket_orders/CardReader
//= require_self

jQuery(document).ready(function($) {

$('#admin_ticket_order_form').each(function() {

    $.fn.setup_code_input = function() {

      $(this).on('blur',function() {
        price = this.id.replace('ticket_class_code','price_override')
        price_field = $('#'+price);
        price_field.val(Number($(this).attr('data-q-ticket_price')).toFixed(2));
        recalculate_row_total(order_type,$(this).parents('.line_item'));
      });
    }

    $.fn.setup_recalculate_row = function() {
      $(this).on('blur',function() {
        recalculate_row_total(order_type,$(this).parents('.line_item'));
      });
    }
    var order_type = 'ticket_order'

    // setup_address_autocompletes('ticket_order');

    // setup_line_item_row_control('ticket_order');

    setup_payment_form();

    $('input.code-input').setup_code_input();

    $('#ticket_line_items').on('cocoon:after-insert', function(e, insertedItem) {
      $(insertedItem).find('input.code-input').setup_code_input();
      $(insertedItem).find('input.ticket_count').setup_recalculate_row();
    });

    $('input.ticket_count,input.price_override').setup_recalculate_row();

  });

/*
  $('#admin_membership_order_form').each(function() {

    order_type = 'membership_order'

    setup_address_autocompletes(order_type);

    setup_payment_form();

    setup_gift_form(order_type)

  });

  $('#admin_flex_pass_order_form').each(function() {

    order_type = 'flex_pass_order'

    setup_address_autocompletes(order_type);

    setup_payment_form();

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

*/
  setup_gift_form();


  $('#update_note_control').hide();

  $('#update_note').click(function() {
      $('#note_control').hide();
      $('#update_note_control').show('slow');
      return false;
    });


});

