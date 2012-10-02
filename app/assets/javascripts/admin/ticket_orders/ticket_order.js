var order_type = 'ticket_order';

function formatCurrency(num) {
  num = num.toString().replace(/\$|\,/g, '');
  if (isNaN(num))
    num = "0";
  sign = (num == (num = Math.abs(num)));
  num = Math.floor(num * 100 + 0.50000000001);
  cents = num % 100;
  num = Math.floor(num / 100).toString();
  if (cents < 10)
    cents = "0" + cents;
  for (var i = 0; i < Math.floor((num.length - (1 + i)) / 3); i++)
    num = num.substring(0, num.length - (4 * i + 3)) + ',' +
        num.substring(num.length - (4 * i + 3));
  return (((sign) ? '' : '-') + '$' + num + '.' + cents);
}

function recalculate_all_row_totals(order_type) {
  jQuery('input.autocomplete_tccode').each(function() {
    var ticket_class_code_input = jQuery(this);
    ticket_class_code_input.val('');
    var my_tr = ticket_class_code_input.parents('tr');
    recalculate_row_total(order_type,my_tr);
  });
}

function recalculate_row_total(order_type, row) {
  var tds = row.children('td');
  var production_code = jQuery('#' + order_type + '_production_code').val();
  var performance_code_input = jQuery('#' + order_type + '_performance_code');
  var ticket_class_code_input = tds.children('input.autocomplete_tccode');
  var ticket_class_code = '';
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
    ticket_class_code = tds.children('input.autocomplete_tccode').val();
  }
  if (ticket_class_code.length < 1) {
    row.removeAttr('price');
    row.removeAttr('ticket_type');
  } else {
    var price_override_input = tds.children('input.price_override');
    if (row.attr('ticket_type') != 'Donation') {
      price_override_input.attr('disabled', 'disabled');
      price_override_input.val('');
    } else {
      price_override_input.removeAttr('disabled');
    }
    var ticket_count = tds.children('input.ticket_count').val();
    var ticket_price = tds.children('input.price_override').val() || row.attr('price');
    var line_price = 1 * ticket_count * ticket_price;
  }
  row.children('td.total').text(formatCurrency(line_price));
}

function add_autocomplete_tccode(order_type, tccode_input) {
  tccode_input.autocomplete(tccode_input.attr('autocomplete_url'), {
    cacheLength:0,
    matchContains:1,//also match inside of strings when caching
    mustMatch:1,//allow only values from the list
    removeInitialValue:0,//when first applying $.autocomplete
    formatItem: function(row, i, max) {
      return "" + row[0] + " -- " + row[1];
    },
    extraParams:{performance_code:function() {
      return jQuery('#' + order_type + '_performance_code').val();
    }},
    width: 400
  }).result(function(event, data, formatted) {
    if (data) {
      my_tr = tccode_input.parents('tr');
      my_tr.attr('price', data[3]);
      my_tr.attr('ticket_type', data[2]);
    }
    recalculate_row_total(order_type, my_tr);
  });
}

function add_autocomplete(order_type) {
  jQuery(function($) {
    //autocomplete

    input = $('#' + order_type + '_performance_code');
    /*input.autocomplete(input.attr('autocomplete_url'), {
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
*/
  });
}

function show_proper_payment_form() {
  jQuery(function($) {
    $('#payment_forms').children('div').each(function() {
      $(this).hide();
    });
    switch ($('#ticket_order_payment_type').val()) {
      case 'Credit Card':
        $('#credit_card_payment_form').show();
        break;
      case 'Cash':
        $('#cash_payment_form').show();
        break;
      case 'FlexPass':
        $('#flex_pass_payment_form').show();
        break;
      case 'Membership':
        $('#membership_payment_form').show();
        break;
    }
  });
}

var add_item_callback = function(added_item){
  added_item.find('input.autocomplete_tccode').each(function() {
    add_autocomplete_tccode(order_type, jQuery(this));
  });
}

jQuery(document).ready(function($) {
  $("#ticket_order_production_code").autocomplete({
      source: function(request, response){
        $.ajax({
          url: $("#ticket_order_production_code").attr('autocomplete_url'),
          datatype:"jsonp",
          data: {
            q: request.term
          },
          success: function( data ) {
            response( $.map( data, function( item ) {
              return {
                label: item.code  + ' [' + item.name + ", " + item.theater + ']',
                value: item.code
              }
            }));
          }
        })
      }
    });
  $("#ticket_order_performance_code").autocomplete({
      source: function(request, response){
        $.ajax({
          url: $("#ticket_order_performance_code").attr('autocomplete_url'),
          datatype:"jsonp",
          data: {
            production_code: $("#ticket_order_production_code").val(),
            q: request.term
          },
          success: function( data ) {
            response( $.map( data, function( item ) {
              return {
                label: item.code,
                value: item.code
              }
            }));
          }
        })
      },
      select: function(ui, event) { alert("hi") }
    });
  // add_autocomplete("ticket_order");
  $('input.ticket_count,input.price_override').live('change',function() {
    recalculate_row_total("ticket_order",$(event.target).parents('tr'))
  });
  $('input.autocomplete_tccode').live('keypress', function() {
    return event.which != 13;
  });
  show_proper_payment_form();
  $('#ticket_order_payment_type').change(function() {
    show_proper_payment_form();
  });
  $('#unclaimed_link').click(function(event) {
    alert('Hooray!');
    event.preventDefault();
  });
});
