//= require utility
//= require orders/payments
//= require admin/address_utility
//= require admin/ticket_orders/CardReader
//= require_self


var order_type = 'membership_order';

setup_address_autocompletes(order_type);

setup_payment_form(order_type);

