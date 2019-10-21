function recalculate_ga_total() {
  sum = 0.00
  $(".total").each(function() {
    sum += parseFloat($(this).text().replace("$",""))

  });
  var formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  });
  $('#order_total').text(formatter.format(sum));
}

function recalculate_row_total(order_type, row) {
  console.log("Row total called")
  var tds = row.children('.columns');
  var performance_code_input = jQuery('#' + order_type + '_performance_code');
  var ticket_class_code_input = tds.find('input.code-input');
  var price_input = tds.find('input.price');
  var ticket_class_code = '';
  var ticket_type = tds.find('input.ticket_types').val();
  line_price = 0;
  var performance_code;
  ticket_class_code = ticket_class_code_input.val();

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
  recalculate_ga_total()
}

function recalculate_all_row_totals(order_type) {
  jQuery('.line_item').each(function() {
    recalculate_row_total(order_type,this);
  });
}

