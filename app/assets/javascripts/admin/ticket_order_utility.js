
function add_autocomplete_tccode(order_type, tccode_input) {
  found_data = null
  tccode_input.autocomplete({
      delay: 250,
      autoFocus: true,
      source: function(request, response) {
        $.ajax({
          url: u,
          datatype:"jsonp",
          data: {
            performance_code: $("#"+order_type+"_performance_code").val(),
            q: request.term
          },
          success: function( data ) {
             found_data = data
             response( $.map( data, function( item ) {
                return {
                  label: item.code + " " + item.name,
                  value: item.code,
                  ticket_price: item.ticket_price,
                  ticket_type: item.ticket_type
                }
              }));
          }
        })
      },
      select: function(event, ui) {
        my_tr = $(event.target).parents('tr');
        my_tr.attr('price', ui.item.ticket_price);
        my_tr.attr('ticket_type', ui.item.ticket_type);
        recalculate_row_total(order_type, my_tr)
      }
    });
    tccode_input.live('keypress', function() {
      return event.which != 13;
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


function recalculate_all_row_totals(order_type) {
  jQuery('input.autocomplete_tccode').each(function() {
    var ticket_class_code_input = jQuery(this);
    ticket_class_code_input.val('');
    var my_tr = ticket_class_code_input.parents('tr');
    recalculate_row_total(order_type,my_tr);
  });
}


var add_item_callback = function(added_item){
  added_item.find('input.autocomplete_tccode').each(function() {
    add_autocomplete_tccode(order_type, jQuery(this));
  });
}


function setup_ticket_autocompletes(order_type) {
  jQuery(document).ready(function($) {
    $("#"+order_type+"_production_code").autocomplete({
        delay: 250,
        autoFocus: true,
        source: function(request, response){
          $.ajax({
            url: $("#"+order_type+"_production_code").attr('autocomplete_url'),
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
        },
        select: function(ui, event) {
          $("#"+order_type+"_performance_code").val("")
          $(".autocomplete_tccode").val("")
          $(".total").val("$0.00")
          $(".ticket_count").val("0")
          recalculate_all_row_totals(order_type)
        }
      });
    $("#"+order_type+"_performance_code").autocomplete({
        delay: 250,
        autoFocus: true,
        source: function(request, response){
          $.ajax({
            url: $("#"+order_type+"_performance_code").attr('autocomplete_url'),
            datatype:"jsonp",
            data: {
              production_code: $("#"+order_type+"_production_code").val(),
              q: request.term
            },
            success: function( data ) {
              response( $.map( data, function( item ) {
                return {
                  label: item.fdate + " " + item.ftime + " (" + item.number_left + " remaining)",
                  value: item.code
                }
              }));
            }
          })
        },
        select: function(ui, event) {
          $(".autocomplete_tccode").val("")
          $(".total").val("$0.00")
          $(".ticket_count").val("0")
          recalculate_all_row_totals(order_type)
        }
      });
    $(".autocomplete_tccode").each(function(index, domElement) {
        u = $(domElement).attr("autocomplete_url")
        add_autocomplete_tccode(order_type, $(domElement))
      });
  });

  $('input.autocomplete_tccode').live('keypress', function() {
    return event.which != 13;
  });

};


replace_ids = function(s){
  var new_id = new Date().getTime();
  return s.replace(/NEW_RECORD/g, new_id);
}


function setup_line_item_row_control() {
  /*
  var myrules = {
    '.remove': function(e){
      el = Event.findElement(e);
      target = el.href.replace(/.*#/, '.')
      el.up(target).hide();
      if(hidden_input = el.previous("input[type=hidden]")) hidden_input.value = '1'
    },
    '.add_nested_item': function(e){
      el = Event.findElement(e);
      template = eval(el.href.replace(/.*#/, ''))
      var added_item = jQuery($(el.rel).insert({
        bottom: replace_ids(template)
      })).children().last();
      add_item_callback && add_item_callback(added_item);
    }
  }
  */
  jQuery(document).ready(function($) {
    $(".add_nested_item").on("click", function(e){
      el = e.toElement;
      console.debug(el);
      template = eval(el.href.replace(/.*#/, ''))
      var added_item = $("#ticket_line_items tbody").append(replace_ids(template)).children().last();
      add_item_callback && add_item_callback(added_item);
      return true;
    });
  });
}

