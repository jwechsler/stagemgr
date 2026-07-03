//= require orders/payments
//= require_this

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
  var tds = row.children('.cell');
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

function show_gift_form() {
  e = $("#gift_information");
  v = $(".third_party_checkbox input.boolean").each(function() {
    if ($(this).is(':checked')) {
      e.removeClass("hide");
    } else {
      e.addClass('hide');
    }
  })
}

function setup_gift_form() {
    $(".third_party_checkbox input").change(function() {
      show_gift_form();
    });
    show_gift_form();
}

function setup_totals(for_general_admission = false) {
  $('.ticket_line_item select').change(function() {
    calculate_ticket_totals(for_general_admission);
  });
  $('.price_override').change(function() {
    calculate_ticket_totals(for_general_admission);
  });
  
  calculate_ticket_totals(for_general_admission);
}

function calculate_ticket_totals(for_general_admission = false) {
  var qty = 0
  var total = 0.0
  var formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  });
  $('.ticket_line_item').each(function(idx) {
    tc = for_general_admission ? $(this).find('.ticket_count').val() : $(this).find('.ticket_count').text()
    line_qty = parseInt(tc)
    qty += line_qty
    var price_input = 0.0
    var price_input_ctl = $(this).find('span.ticket_price')
    if (price_input_ctl.length==0) { // this is a donation ticket class
      price_input = $(this).find('.price_override').val()
      if (price_input == "") {
        price_input = $(this).find('.default_price_override').val();
      }
      price_input = parseFloat(price_input)
    }
    else {
      price_input = parseFloat(price_input_ctl.text().replace(/^\$/g,''));
    }
    
    if (!isNaN(price_input)) { total += price_input*line_qty }
  });

  $('#ticket_quantity').text(isNaN(qty) ? '' : qty);
  $('#order_total').text(isNaN(total) ? '' : formatter.format(total));

}


function recalculate_all_row_totals(order_type) {
  jQuery('.line_item').each(function() {
    recalculate_row_total(order_type,$(this));
  });
}

function set_button_state_for_autocompletes() {
  var allow_submit = false

  $('.ticket_class_ids').each(function(index) {
    if (!allow_submit) {
      found_one = true
      if ($(this).val() == "") {
        found_one = false
      }
      found_one = found_one && ($('#'+this.id.replace('ticket_class_id','ticket_count')).val() > 0)
      allow_submit = allow_submit || found_one
    }
  });

  // Modal dismissal controls ([data-close]) are exempt from order-action
  // gating — the ticket-class selector's close button must always work.
  if (allow_submit) {
    $('input[type="submit"].order-submit-button, button').not('[data-close]').prop('disabled', false);
    $('#hold_button').prop('disabled', false);
  } else {
    $('input[type="submit"].order-submit-button, button').not('[data-close]').prop('disabled', true);
    $('#hold_button').prop('disabled', true);
  }

}


// The public site wrapper (ext_site_wrapper) yields :js twice, so this file
// can be included twice on public order pages — bind the ready hook once.
if (!window.__orders_common_ready_bound) {
  window.__orders_common_ready_bound = true;
  jQuery(document).ready(function($) {
    setup_payment_form();
    setup_gift_form();
  });
}

