//= require orders/payments
//= require_this

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

  $('#ticket_quantity').text(qty);
  $('#order_total').text(formatter.format(total));

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

  if (allow_submit) {
    $('input[type="submit"].order-submit-button, button').prop('disabled', false);
    $('#hold_button').prop('disabled', false);
  } else {
    $('input[type="submit"].order-submit-button, button').prop('disabled', true);
    $('#hold_button').prop('disabled', true);
  }

}


jQuery(document).ready(function($) {
  setup_payment_form();
  setup_gift_form();
  
});

