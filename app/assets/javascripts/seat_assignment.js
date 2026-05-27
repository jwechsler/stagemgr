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
              update_unavailable_seats(response['unavailable']);

              if (is_reserved_seating_mode()) {
                // Remove the per-seat row for this SeatAssignment.
                var $row = $('#ticket-display .ticket_line_item[data-seat-assignment-id="' + response['id'] + '"]')
                $row.remove()
                // Rebuild the seatlocations label from remaining rows.
                var remaining = []
                $('#ticket-display .ticket_line_item').each(function() {
                  var label = $(this).find('.cell.small-6').text().split(' / ')[0]
                  if (label) remaining.push(label.trim())
                })
                $("#seatlocations").text(remaining.join(", "))
              } else {
                current_count = $("#ticket_class_qty_display_"+ticket_class_id).text()
                if (current_count===undefined) {
                  current_count = 0
                } else  {
                  current_count = Number(current_count) - 1
                }
                $(".ticket_class_count_"+ticket_class_id).val(current_count);
                $("#ticket_class_qty_display_"+ticket_class_id).text(current_count);
                if (current_count <= 0 && typeof hide_ticket_class_row === "function") { hide_ticket_class_row(ticket_class_id); }
                c_locations = $("#seatlocations").text().trim()
                new_seat = $(e_reference).data('location')
                c_locations = c_locations.replace(',' + new_seat, '')
                c_locations = c_locations.replace(new_seat, '')

                if (c_locations[0]==',') {
                  c_locations = c_locations.substr(1)
                }
                $("#seatlocations").text(c_locations)
              }

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
    var ticket_type = $(this).data("ticket-type")
    var price_override = ""
    if (ticket_type === "Donation") {
      var priceInput = $(this).closest(".grid-x").find(".donation-price-override")
      if (priceInput.length > 0) {
        price_override = priceInput.val()
      }
    }

    $('#ticket-modal').foundation('close');
    accessible_setting = ($("#convert-accessible").is(":checked") && $("#accessible").is(":visible")) ? $("#convert-accessible").val() : ""
    console.log("accessible is " + accessible_setting)
    $.post( reserve_url(),
      { 'id': $('#ticket-modal').data('assignment-id'),
         'order_uuid': ticket_order_id(),
         'ticket_class_id': ticket_class_id,
         'accessible':accessible_setting,
         'price_override': price_override
      }, function( response, status ) {
        e_reference = '[data-assignment-id='+response['id']+']'
        data_key = response['id']+','+response['status']
        update_unavailable_seats(response['unavailable']);
        console.log("result = " + response['status'])
        if (response['status'] == 'unavailable') {
          alert("Sorry, that seat is no longer available")
        } else if (response['status'] == 'assigned') {
          if (is_reserved_seating_mode()) {
            var tcInfo = find_ticket_class_info(ticket_class_id) || {}
            var row = build_reserved_seat_row({
              seat_assignment_id: response['id'],
              seat_label: response['seat_label'] || $(e_reference).data('location'),
              ticket_class_id: ticket_class_id,
              ticket_class_name: tcInfo['class_name'],
              ticket_price: tcInfo['raw_ticket_price'],
              price_override: response['price_override'],
              ticket_line_item_id: response['ticket_line_item_id'] || null
            })
            $("#ticket-display").append(row)
            c_locations = $("#seatlocations").text().trim()
            if (c_locations != '') { c_locations = c_locations + ', ' }
            $("#seatlocations").text(c_locations + ($(e_reference).data('location') || ''))
          } else {
            current_count = $("#ticket_class_qty_display_"+ticket_class_id).text()
            if (current_count===undefined) { current_count = "0" }
            current_count = Number(current_count) + 1
            $(".ticket_class_count_"+ticket_class_id).val(current_count);
            $("#ticket_class_qty_display_"+ticket_class_id).text(current_count);
            if (typeof show_ticket_class_row === "function") { show_ticket_class_row(ticket_class_id); }
            if (response['price_override']) {
              var priceSpan = document.querySelector('.ticket_line_item[data-ticket-class-id="' + ticket_class_id + '"] .ticket_price')
              if (priceSpan) { priceSpan.textContent = format_currency(response['price_override']); }
            }
            c_locations = $("#seatlocations").text().trim()
            if (c_locations != '') { c_locations = c_locations + ',' }
            $("#seatlocations").text(c_locations + $(e_reference).data('location'))
          }
          calculate_ticket_totals();
          set_button_state_for_autocompletes();

          update_seating_attributes(e_reference, response['status'])
        } else {
          $( e_reference ).mapster('deselect')
        }
      });

  });
}

function format_currency(value) {
  var n = Number(value)
  if (isNaN(n)) { return value }
  return "$" + n.toFixed(2)
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

// Reflect the server's current "unavailable for this order" list on the
// seatmap so the fill color of every affected seat stays in sync with
// reality — not just the one the user clicked.
function update_unavailable_seats(unavailable_ids) {
  if (!unavailable_ids) return
  $.each(unavailable_ids, function(_idx, value) {
    var ref = '[data-assignment-id=' + value + ']'
    var $el = $(ref)
    if ($el.length === 0) return
    var current = $el.data('status')
    if (current !== 'unavailable') {
      update_seating_attributes(ref, 'unavailable')
    }
    var unavail_key = value + ',unavailable'
    $el.attr('data-key', unavail_key).data('key', unavail_key)
  })
  // Any previously-unavailable seat the server no longer reports is now
  // available again (e.g., after we released one of our own holds).
  var current_unavailable = unavailable_ids.map(String)
  $('#seatingmap circle[data-status="unavailable"]').each(function() {
    var id = String($(this).data('assignment-id'))
    if (current_unavailable.indexOf(id) === -1) {
      var ref = '[data-assignment-id=' + id + ']'
      update_seating_attributes(ref, 'available')
      var key = id + ',available'
      $(this).attr('data-key', key).data('key', key)
    }
  })
}

function is_reserved_seating_mode() {
  // A rendered seatmap with seat circles is the authoritative signal that
  // we're in reserved-seating mode. The admin "new for production" flow
  // renders #ticket-line-item-merge before a performance (and therefore
  // before the seatmap) is selected, so attribute-based detection on that
  // element can't be relied on here.
  if (document.querySelectorAll('#seatingmap circle').length > 0) return true
  var el = document.getElementById("ticket-line-item-merge")
  return !!(el && el.hasAttribute("data-reserved-seating"))
}

function find_ticket_class_info(ticket_class_id) {
  var data = $("#ticket-items").data("line-items")
  if (!data) return null
  var parsed = typeof data === "string" ? $.parseJSON(data) : data
  var hit = null
  $.each(parsed, function(_k, v) { if (String(v.id) === String(ticket_class_id)) { hit = v } })
  return hit
}

function build_reserved_seat_row(seatInfo, index) {
  // seatInfo: { seat_assignment_id, seat_label, ticket_class_id, ticket_class_name,
  //             ticket_price, price_override, ticket_line_item_id }
  var saId = seatInfo.seat_assignment_id
  // Rails strong parameters silently drops nested-attributes keys that aren't
  // integer-shaped, so key each TLI group by the numeric SeatAssignment id.
  var key = String(saId)
  var row = document.createElement("div")
  row.setAttribute("class", "grid-x grid-padding-x ticket_line_item line_item")
  row.setAttribute("data-ticket-class-id", seatInfo.ticket_class_id)
  row.setAttribute("data-seat-assignment-id", saId)

  function hidden(nameKey, value) {
    var i = document.createElement("input")
    i.setAttribute("type", "hidden")
    i.setAttribute("name", "ticket_order[ticket_line_items_attributes][" + key + "][" + nameKey + "]")
    i.value = value == null ? "" : value
    return i
  }
  if (seatInfo.ticket_line_item_id) { row.appendChild(hidden("id", seatInfo.ticket_line_item_id)) }
  row.appendChild(hidden("ticket_class_id", seatInfo.ticket_class_id))
  row.appendChild(hidden("ticket_count", 1))
  row.appendChild(hidden("seat_assignment_id", saId))
  if (seatInfo.price_override != null && seatInfo.price_override !== "") {
    row.appendChild(hidden("price_override", seatInfo.price_override))
  }

  var label = seatInfo.seat_label ? (seatInfo.seat_label + " / ") : ""
  row.appendChild(create_column("6", label + (seatInfo.ticket_class_name || "")))

  var qtyCol = create_column("2", "")
  qtyCol.style.textAlign = "right"
  var qty = document.createElement("span")
  qty.setAttribute("class", "ticket_count right")
  qty.appendChild(document.createTextNode("1"))
  qtyCol.appendChild(qty)
  row.appendChild(qtyCol)

  var priceCol = create_column("3", "")
  priceCol.style.textAlign = "right"
  var price = document.createElement("span")
  price.setAttribute("class", "ticket_price right")
  var effective = (seatInfo.price_override != null && seatInfo.price_override !== "") ? seatInfo.price_override : seatInfo.ticket_price
  price.appendChild(document.createTextNode(format_currency(effective)))
  priceCol.appendChild(price)
  row.appendChild(priceCol)

  var actionCol = create_column("1", "")
  var remove = document.createElement("a")
  remove.setAttribute("href", "#")
  remove.setAttribute("class", "remove-reserved-seat")
  remove.setAttribute("data-seat-assignment-id", saId)
  remove.appendChild(document.createTextNode("✕"))
  actionCol.appendChild(remove)
  row.appendChild(actionCol)

  return row
}

function populate_reserved_seat_rows() {
  $("#ticket-display").empty()
  var locations = []
  $("#ticket-line-item-merge .reserved-seat-entry").each(function() {
    var $e = $(this)
    var row = build_reserved_seat_row({
      seat_assignment_id: $e.data("seat-assignment-id"),
      seat_label: $e.data("seat-label"),
      ticket_class_id: $e.data("ticket-class-id"),
      ticket_class_name: $e.data("ticket-class-name"),
      ticket_price: $e.data("ticket-price"),
      price_override: $e.data("price-override"),
      ticket_line_item_id: $e.data("ticket-line-item-id")
    })
    $("#ticket-display").append(row)
    if ($e.data("seat-label")) { locations.push($e.data("seat-label")) }
  })
  $("#seatlocations").text(locations.join(", "))
}

function populate_ticket_order(data) {

  if (is_reserved_seating_mode()) {
    populate_reserved_seat_rows()
    calculate_ticket_totals()
    set_button_state_for_autocompletes()
    return
  }

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
    row.setAttribute("data-ticket-class-id", ticket_class_id)
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
    var priceOverride = $("#ticket-line-item-merge-" + ticket_class_id).data("price-override")
    var hasOverride = priceOverride !== undefined && priceOverride !== null && priceOverride !== ""
    price.appendChild(document.createTextNode(hasOverride ? format_currency(priceOverride) : val['ticket_price']))
    row.appendChild(create_column("3", "", price))

    if (Number(qty_val) === 0) {
      row.style.display = "none"
    }

    $("#ticket-display").append(row)
  });
  calculate_ticket_totals();
  set_button_state_for_autocompletes();
}

function show_ticket_class_row(ticket_class_id) {
  var row = document.querySelector('.ticket_line_item[data-ticket-class-id="' + ticket_class_id + '"]')
  if (row) { row.style.display = "" }
}

function hide_ticket_class_row(ticket_class_id) {
  var row = document.querySelector('.ticket_line_item[data-ticket-class-id="' + ticket_class_id + '"]')
  if (row) { row.style.display = "none" }
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
  initialize_donation_override_edit();
  initialize_remove_reserved_seat();
});

function initialize_remove_reserved_seat() {
  $(document).off("click.removeReservedSeat", ".remove-reserved-seat");
  $(document).on("click.removeReservedSeat", ".remove-reserved-seat", function(e) {
    e.preventDefault();
    var saId = $(this).data("seat-assignment-id");
    // Reuse the existing seatingmap-click release path by locating the circle
    // and triggering its click; the handler's "assigned" branch does the POST
    // + row removal + totals update in one place.
    var $circle = $('#seatingmap circle[data-assignment-id="' + saId + '"]');
    if ($circle.length === 0) {
      // Fallback: if circle isn't in DOM (unlikely), POST release directly.
      $.post(release_url(), { id: saId, order_uuid: ticket_order_id() }, function() {
        $(".ticket_line_item[data-seat-assignment-id='" + saId + "']").remove();
        calculate_ticket_totals();
      });
      return;
    }
    $circle.trigger('click');
  });
}

function initialize_donation_override_edit() {
  $(document).off("change.donationOverride", ".donation-price-override-edit");
  $(document).on("change.donationOverride", ".donation-price-override-edit", function() {
    var $input = $(this);
    var url = $input.data("update-url");
    var sa_id = $input.data("seat-assignment-id");
    var $status = $input.closest(".grid-x").find(".donation-override-status");
    $status.text("Saving…");
    $.post(url, {
      id: sa_id,
      order_uuid: ticket_order_id(),
      price_override: $input.val()
    })
    .done(function(response) {
      $status.text("Saved");
      if (typeof calculate_ticket_totals === "function") { calculate_ticket_totals(); }
      setTimeout(function() { $status.text(""); }, 1500);
    })
    .fail(function(xhr) {
      var msg = "Error";
      try { msg = JSON.parse(xhr.responseText).message || msg; } catch (e) {}
      $status.text(msg);
    });
  });
}




