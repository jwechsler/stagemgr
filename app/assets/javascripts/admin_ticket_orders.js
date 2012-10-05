//= require jquery-ui
//= require utility
//= require admin/ticket_order_utility
//= require orders/payments
//= require admin/ticket_orders/CardReader
//= require_self

var order_type = 'ticket_order';


   /*function add_autocomplete(order_type) {
  jQuery(function($) {
    //autocomplete

    input = $('#' + order_type + '_performance_code');
 input.autocomplete(input.attr('autocomplete_url'), {
      cacheLength:0,
      matchContains:1,//also match inside of strings when caching
      mustMatch:1,//allow only values from the list
      removeInitialValue:0,//when first applying $.autocomplete
      formatItem: function(row, i, max) {
        return "" + row[0] + " -- " + row[1];
      },
      extraParams:{production_code:function() {
        return $('#' + order_type + '_production_code').val()
      }},
      width: 400
    }).result(function(event, item) {
          $('input.autocomplete_tccode').each(function() {
            $(this).val('')
          });
          recalculate_all_row_totals(order_type);
        });
    $('input.autocomplete_tccode').each(function() {
      add_autocomplete_tccode(order_type, $(this));
    });

  });
}
*/

setup_ticket_autocompletes(order_type)

setup_line_item_row_control(order_type)

// add_autocomplete("ticket_order");
$('input.ticket_count,input.price_override').live('change',function() {
  recalculate_row_total("ticket_order",$(event.target).parents('tr'))
});


show_proper_payment_form();
$('#ticket_order_payment_type').change(function() {
  show_proper_payment_form();
});
$('#unclaimed_link').click(function(event) {
  event.preventDefault();
});

