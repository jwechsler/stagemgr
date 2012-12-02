//= require admin/orders_common
//= require admin/ticket_order_utility
//= require_self

var order_type = 'ticket_order';

setup_ticket_autocompletes(order_type);

setup_address_autocompletes(order_type);

setup_line_item_row_control(order_type);

setup_payment_form(order_type);

// add_autocomplete("ticket_order");
$('input.ticket_count,input.price_override').live('change',function() {
  recalculate_row_total(order_type,$(event.target).parents('tr'))
});

$('#unclaimed_link').click(function(event) {
  event.preventDefault();
});

