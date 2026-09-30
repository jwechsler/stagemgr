//= require application

function count_assigned() {
  count = 0
  $("#seatingmap area").each(function () {
    if ($(this).data('status') == 'assigned') {
      count = count + 1
    }
  });
  return count;
}

function max_assignable() {
  return $('#seating-config').data('max-quantity')
}

function ticket_order_id() {
  return $('#seating-config').data('order-id')
}

function reserve_url() {
  return $('#seating-config').data('reserve-url')
}

function release_url() {
  return $('#seating-config').data('release-url')
}

function update_seating_submit_button(seating_complete) {
  $('.seating-required').prop('disabled',!seating_complete)
  if (seating_complete) {
    $('.seating-required').attr('value','Place Order')
  } else {
    $('.seating-required').attr('value','Assign Seats')
  }
}

// Seats with a reserve/release request in flight, keyed by assignment id.
// A second click on the same seat (a double click, or the modal's class
// button clicked twice) is ignored until the first request settles; other
// seats stay clickable. Kept on window because seat_map is bundled into both
// seat_assignment.js and reseating.js.
window.pending_seat_ids = window.pending_seat_ids || {}

function is_seat_pending(assignment_id) {
  return window.pending_seat_ids[String(assignment_id)] === true
}

function mark_seat_pending(assignment_id) {
  window.pending_seat_ids[String(assignment_id)] = true
  $('#seatingmap circle[data-assignment-id="' + assignment_id + '"]').addClass('seat-pending')
}

function clear_seat_pending(assignment_id) {
  delete window.pending_seat_ids[String(assignment_id)]
  $('#seatingmap circle[data-assignment-id="' + assignment_id + '"]').removeClass('seat-pending')
}

// Forget every in-flight seat, e.g. when the seatmap is swapped for another
// performance: the old circles are gone and their ids no longer apply.
function reset_pending_seats() {
  window.pending_seat_ids = {}
}

// Friendly message for a failed reserve/release. The server's own message
// (a 422 zone or class rejection) is written for patrons, so prefer it.
function seat_request_failed(xhr) {
  var msg = "Sorry, we couldn't update that seat. Please try again."
  try {
    var parsed = JSON.parse(xhr.responseText)
    if (parsed && parsed.message) { msg = parsed.message }
  } catch (e) {
    console.log("seat request failed: " + xhr.status)
  }
  alert(msg)
}

function update_seating_attributes(e_reference, status) {
  
  old_status = $(e_reference).data('status')
  $(e_reference).removeClass(old_status)
  $(e_reference).data('status', status)
  $(e_reference).addClass(status)
  // console.log('Updating ' + $( e_reference ).data('assignment-id') + ' from ' + old_status + ' to ' + status)
}

function update_mapster_attributes(e_reference, data_key, status) {
  console.log('why is mapster still running? (update_mapster_attributes)')
  if (data_key != '') {
    $( e_reference ).attr('data-key', data_key)
    $( e_reference ).data('key', data_key)
  }
  $( e_reference ).attr('data-status', status)
  $( e_reference ).data('status',status)
  if (status == 'available') {
    $( e_reference).mapster('deselect')
  } else {
    $( e_reference ).mapster('highlight', true)
  }
  // $( e_reference ).mapster('highlight', false)
}

function update_selected() {
  $("#seatingmap area[data-status='assigned']").mapster('select')
}

function mapster_options() {
  console.log('why is mapster still running? (mapster_options)')
  return {
    mapKey: 'data-key',
    fillColor: '00ff00',
    fillOpacity: 0.4,

    areas: [{
              key: 'assigned',
              staticState: true,
              render_select: {
                fillCOlor: '00ff00',
                fillOpacity: 0.4
              },render_highlight: {
                fillColor: '00ff00',
                fillOpacity: 0.4
              }

            },{
              key: 'unavailable',
              staticState: true,
              isSelectable: false,
              render_highlight: {
                fillColor: '222222',
                fillOpacity: 0.3
              },
              render_select: {
                fillColor: '222222',
                fillOpacity: 0.3
              }
            },{
              key: 'available',
              isSelectable: true,
              staticState: true,
              render_select: {
                fillColor: '000000',
                fillOpacity: 0.0
              },render_highlight: {
                fillColor: '000000',
                fillOpacity: 0.0
              },
            },{
              key: 'releasing',
              isSelectable: true,
              staticState: true,
              render_select: {
                fillColor: '0000ff',
                fillOpacity: 0.4
              }
            }]
  };
}

function initialize_seatingmap() {
  $("#ticket-modal").foundation();
}



