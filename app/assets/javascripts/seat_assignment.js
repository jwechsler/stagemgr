//= require seat_map

function count_assigned() {
  count = 0
  $("#seatingmap area").each(function () {
    if ($(this).data('status') == 'assigned') {
      count = count + 1
    }
  });
  return count;
}

function performance_id(perf_id) {

  if (perf_id === undefined) {
    perf_id = $("#performance_id").val()
  } else {
    $("#performance_id").val(perf_id)
  }
  return perf_id
}

function reserve_url() {
  return $('#seating-config').data('reserve-url').replace('-~-',$("#performance_id").val())
}

function release_url() {
  return $('#seating-config').data('release-url').replace('-~-',$("#performance_id").val())
}

function seat_assignments_url() {
  return $('#seating-config').data('seat-assignments-url').replace('-~-',$("#performance_id").val()) + "?ticket_order_uuid=" + ticket_order_id()
}

function ticket_classes_url() {
  return $('#seating-config').data('ticket-classes-url').replace('-~-',$("#performance_id").val())
}

function release_temporary_holds_url() {
  return $('#seating-config').data('release-temporary-url')
}

function update_seating_submit_button(seating_complete) {
  $('.seating-required').prop('disabled',!seating_complete)
  if (seating_complete) {
    $('.seating-required').attr('value','Place Order')
  } else {
    $('.seating-required').attr('value','Assign Seats')
  }
}

function release_temporary_holds_by_uuid(uuid, perf_id) {
  console.log("releasing for all but " + performance_id(perf_id))
  $.post( release_temporary_holds_url(),
    { 'order_uuid': uuid,
      'exclude_performance_id': performance_id(perf_id)
    }, function( response, status ) {
      console.log ("temporary hold release = " + response['status'])
    });
}

function initialize_seating_assignment() {

  $(document).on('closed.fndtn.reveal', '[data-reveal]', function () {
    var modal = $(this);
    //$('img.seatingmap').mapster('rebind',mapster_options());

  });

  $('#seatingmap circle').click( function(e) {
    e.preventDefault();
    // var data = $('#seatingmap').data('maphilight') || {};
    // data.alwaysOn = true;
    console.log("assignment_id on click = " + $(this).data('assignment-id'));
    e_reference = '[data-assignment-id=' + $(this).data('assignment-id') + ']'

    starting_status = String($(this).data('status'));
    console.log("starting status is " + starting_status)

    data_key = $(this).data('key')
    switch (starting_status) {
      case "available":
        $("#seat-location").text($(this).data('location'));
        accessible = $(this).data('accessible')
        if (accessible) {
          $("#accessible").show()
        } else {
          $("#accessible").hide()
        }

        $("#ticket-modal").data('assignment-id', $( this ).data('assignment-id'));
        $('#ticket-modal').foundation('open');
        break;
      case "assigned":
        $.post( release_url(),
          { 'id': $( this ).data('assignment-id'),
             'order_uuid': ticket_order_id()
          }, function( response, status ) {
            e_reference = '[data-assignment-id='+response['id']+']'

            if (response['status'] == 'available') {
              ticket_class_id = response['ticket_class_id']
              data_key = response['id'] + ',' + response['status']

              update_seating_attributes(e_reference, response['status'])
              
              current_count = $("#ticket_class_qty_display_"+ticket_class_id).text()

              if (current_count===undefined) {
                current_count = 0
              } else  {
                current_count = Number(current_count) - 1
              }
              $(".ticket_class_count_"+ticket_class_id).val(current_count);
              $("#ticket_class_qty_display_"+ticket_class_id).text(current_count);
              c_locations = $("#seatlocations").text().trim()
              new_seat = $(e_reference).data('location')
              c_locations = c_locations.replace(',' + new_seat, '')
              c_locations = c_locations.replace(new_seat, '')

              if (c_locations[0]==',') {
                c_locations = c_locations.substr(1)
              }
              $("#seatlocations").text(c_locations)

              calculate_ticket_totals();
              set_button_state_for_autocompletes();
             
            }

          });
          break;
    };

  });
  $(".ticket-class-select-button").off("click");
  $(".ticket-class-select-button").click(function() {
    var ticket_class_id = $(this).data("ticket-class")

    $('#ticket-modal').foundation('close');
    accessible_setting = ($("#convert-accessible").is(":checked") && $("#accessible").is(":visible")) ? $("#convert-accessible").val() : ""
    console.log("accessible is " + accessible_setting)
    $.post( reserve_url(),
      { 'id': $('#ticket-modal').data('assignment-id'),
         'order_uuid': ticket_order_id(),
         'ticket_class_id': ticket_class_id,
         'accessible':accessible_setting
      }, function( response, status ) {
        e_reference = '[data-assignment-id='+response['id']+']'
        data_key = response['id']+','+response['status']
        $.each(response['unavailable'], function(index,value) {
          unavail_key = value + ',unavailable'
          $('[data-assignment-id='+value+']').attr('data-key',unavail_key)
          $('[data-assignment-id='+value+']').attr('data-status','unavailable')
          $('[data-assignment-id='+value+']').data('key',unavail_key)
          $('[data-assignment-id='+value+']').data('status','unavailable')
        });
        console.log("result = " + response['status'])
        if (response['status'] == 'unavailable') {
          alert("Sorry, that seat is no longer available")
        } else if (response['status'] == 'assigned') {
          current_count = $("#ticket_class_qty_display_"+ticket_class_id).text()

          if (current_count===undefined) {
            current_count = "0"
          }
          current_count = Number(current_count) + 1
          $(".ticket_class_count_"+ticket_class_id).val(current_count);
          $("#ticket_class_qty_display_"+ticket_class_id).text(current_count);
          c_locations = $("#seatlocations").text().trim()
          if (c_locations != '') {
            c_locations = c_locations + ','
          }
          $("#seatlocations").text(c_locations + $(e_reference).data('location'));
          calculate_ticket_totals();
          set_button_state_for_autocompletes();

          update_seating_attributes(e_reference, response['status'])
          // $( e_reference ).mapster('set', true, data_key)
        } else {
          $( e_reference ).mapster('deselect')
        }
      });

  });
}

function create_column(size, text_content = "", additionalContent = null) {
  col = document.createElement("div")
  col.setAttribute("class","cell small-" + size)
  col.appendChild(document.createTextNode(text_content))
  if (!(additionalContent == null)) {
    col.appendChild(additionalContent)
  }
  return col
}

function get_ticket_classes() {
  tc_data = ""
  $.ajax({
    url: ticket_classes_url(),
    dataType: 'json',
    async: false,
    data: tc_data,
    success: function(data) {
      var line_items = [];
      tc_data = JSON.stringify(data)
      $("#ticket-items").data('line-items',tc_data)
    }
  });
}

function populate_ticket_order(data) {

  if (data === undefined) {
    data = $.parseJSON($("#ticket-items").data('line-items'))
  }
  $("#ticket-display").empty()
  $("#seatlocations").text($("#ticket-line-item-merge").data('seat-assignments'));

  $.each( data, function( key, val ) {
    ticket_class_id = val['id']
    var visible_style
    if (val['web_visible']) {
      visible_style = "front-facing"
    } else {
      visible_style = ""
    }
    var row = document.createElement("div")
    row.setAttribute("class", "grid-x grid-padding-x ticket_line_item line_item " + visible_style)
    row.setAttribute("price", val['ticket_price'])
    row.setAttribute("ticket_type", val['ticket_type'])
    tli_id = $("#ticket-line-item-merge-" + ticket_class_id).data("ticket-line-item-id")
    if (!(tli_id === undefined)) {
      ctl = document.createElement("input")
      ctl.setAttribute("id","ticket_order_line_items_attributes_" + key + "_id")
      ctl.setAttribute("name", "ticket_order[ticket_line_items_attributes][" + key + "][id]")
      ctl.setAttribute("type","hidden")
      ctl.setAttribute("value",tli_id )
      row.appendChild(ctl)
    }
    ctl = document.createElement("input")
    ctl.setAttribute("id", "ticket_order_ticket_line_items_attributes_" + key + "_ticket_class_id")
    ctl.setAttribute("name", "ticket_order[ticket_line_items_attributes][" + key + "][ticket_class_id]")
    ctl.setAttribute("type","hidden")
    ctl.setAttribute("class","ticket_class_ids")
    ctl.setAttribute("value",ticket_class_id )
    row.appendChild(create_column("6",val['class_name'],ctl))
    qty = document.createElement("span")
    qty_val = $("#ticket-line-item-merge-" + ticket_class_id).data("ticket-count")
    if (qty_val===undefined) {
      qty_val = '0'
    }
    qty.setAttribute("id","ticket_class_qty_display_" + ticket_class_id)
    qty.setAttribute("class","ticket_count right")
    qty.appendChild(document.createTextNode(qty_val))
    ctl = document.createElement('input')
    ctl.setAttribute('id',"ticket_order_ticket_line_items_attributes_" + key + "_ticket_count")
    ctl.setAttribute('class',"ticket_count_control ticket_class_count_" + ticket_class_id)
    ctl.setAttribute("value",qty_val)
    ctl.setAttribute("name", "ticket_order[ticket_line_items_attributes][" + key + "][ticket_count]")
    ctl.setAttribute("type","hidden")
    col = create_column("3","")
    col.appendChild(ctl)
    col.appendChild(qty)
    row.appendChild(col)
    price = document.createElement("span")
    price.setAttribute("class","ticket_price right")
    price.appendChild(document.createTextNode(val['ticket_price']))
    row.appendChild(create_column("3", "", price))

    $("#ticket-display").append(row)
  });
  calculate_ticket_totals();
  set_button_state_for_autocompletes();
}

function update_ticketing_panel(perf_id) {
  $('#seatmap-area').empty()
  release_temporary_holds_by_uuid(ticket_order_id())

  $.ajax({
    url: seat_assignments_url(performance_id(perf_id)),
    dataType: "html",
    timeout: 2000,
    success: function(html) {
      $("#seatmap-area").html(html)
      get_ticket_classes()
      populate_ticket_order()
      populate_ticket_selector()
      initialize_seatingmap()
      initialize_seating_assignment()
      console.log("seatmap updated")
    }
  });

  setTimeout(function() {

  }, 600);
}

$(document).ready(function() {
  initialize_seatingmap();
  initialize_seating_assignment();
});




