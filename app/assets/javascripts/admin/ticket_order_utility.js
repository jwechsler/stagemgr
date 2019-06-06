function recalculate_row_total(order_type, row) {
  var tds = row.children('.columns');
  var production_code = jQuery('#' + order_type + '_production_code').val();
  var performance_code_input = jQuery('#' + order_type + '_performance_code');
  var ticket_class_code_input = tds.find('input.code-input');
  var price_input = tds.find('input.price');
  var ticket_class_code = '';
  var ticket_type = tds.find('input.ticket_types').val();
  line_price = 0;
  var performance_code;
  if (production_code.length < 1) {
    performance_code_input.val('');
    ticket_class_code_input.val('');
  } else {
    performance_code = performance_code_input.val();
    if (performance_code.length < 1) {
      ticket_class_code_input.val('');
    }
    ticket_class_code = ticket_class_code_input.val();
  }
  if (ticket_class_code.length > 0) {
    var price_override_input = row.find('input.price');
    if (ticket_type != 'Donation') {
      price_override_input.attr('disabled', 'disabled');
      // price_override_input.val('');
    } else {
      price_override_input.removeAttr('disabled');
    }
    var ticket_count = tds.find('input.ticket_count').val();
    var ticket_price = tds.find('input.price').val() || row.attr('price');
    var line_price = 1 * ticket_count * ticket_price;
  }
  row.find('div.total').text(formatCurrency(line_price));
}


function recalculate_all_row_totals(order_type) {
  jQuery('.line_item').each(function() {
    recalculate_row_total(order_type,this);
  });
}

