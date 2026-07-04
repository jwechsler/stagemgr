//= require seat_map


function commit_reseating_url() {
  return $('#seating-config').data('commit-reseating-url')
}

// Zoned pricing: zones served by the ticket classes already on this order.
// A replacement seat must sit in one of these zones ("*" serves any zone).
function order_class_zones() {
  var raw = $('#seating-config').attr('data-order-class-zones') || '';
  return raw.length ? raw.split(',') : [];
}

function zone_allowed_for_order(seatZone) {
  var zones = order_class_zones();
  if (zones.length === 0) { return true; }
  for (var i = 0; i < zones.length; i++) {
    if (zones[i] === '*' || zones[i] === seatZone) { return true; }
  }
  return false;
}

// Visually dim available seats the order's ticket classes cannot move into.
function mark_zone_blocked_seats() {
  $('#seatingmap circle[data-status="available"]').each(function() {
    var blocked = !zone_allowed_for_order(String($(this).data('zone') || ''));
    $(this).toggleClass('zone-blocked', blocked);
  });
}

function rollback_reseating_url() {
  return $('#seating-config').data('rollback-reseating-url')
}

$(document).ready(function() {
  $("#seating-control").click(function() {
    $('#change-seats').foundation('open');

    setTimeout(function() {
      initialize_seatingmap()
      mark_zone_blocked_seats()
    },1000)

  });

  // reseating click handler
  $('#seatingmap circle').click( function(e) {
    e.preventDefault();
    var data = $('#seatingmap').data('maphilight') || {};
    data.alwaysOn = true;
    e_reference = '[data-assignment-id=' + $(this).data('assignment-id') + ']'

    starting_status = String($(this).data('status'));
    assignment_id = $(this).data('assignment-id')
    data_key = $(this).data('key')
    max_tix = $("#number-of-tickets").text()
    switch (starting_status) {
      case "available":
      case "releasing":
        // Zoned pricing: refuse cross-zone targets client-side; the server
        // enforces the same rule in reserve and commit_reseating.
        var seatZone = String($(this).data('zone') || '');
        if (!zone_allowed_for_order(seatZone)) {
          alert("Seat " + $(this).data('location') + " (zone " + seatZone + ") is not available for your ticket type");
          break;
        }
        $.post( reserve_url(),
              { 'id': assignment_id,
                 'order_uuid': ticket_order_id(),
                 'max_tickets': max_tix
              }, function( response, status ) {
                e_reference = '[data-assignment-id='+response['id']+']'
                data_key = response['id']+','+response['status']
                $.each(response['unavailable'], function(index,value) {
                  unavail_key = value + ',unavailable'
                  $('[data-assignment-id='+value+']').attr('data-key',unavail_key)
                  $('[data-assignment-id='+value+']').attr('data-status','unavailable')
                  $('[data-assignment-id='+value+']').data('key',unavail_key)
                  $('[data-assignment-id='+value+']').data('status','unavailable')
                  // $( '[data-assignment-id='+value+']').mapster('deselect')
                });
                if (response['status'] == 'unavailable') {
                  alert("Sorry, that seat is no longer available")
                } else if (response['status'] == 'assigned') {
                  update_seating_attributes(e_reference, response['status'])
                } else {
                  alert("You can only assign " + max_tix + ((max_tix==1) ? " seat" : " seats"))
                  // $( e_reference ).mapster('deselect')
                }
                // $('img.seatingmap').mapster('rebind',mapster_options())
                $("#updated-seat-list").text(response['current_seat_assignments'])
                num_tix = parseInt(response['ticket_count'])

                if (num_tix == parseInt($("#number-of-tickets").text())) {
                  $("#finalize-seating").removeClass("disabled")
                } else {
                  $("#finalize-seating").addClass("disabled")
                }
              });

        break;
      case "assigned":
        $.post( release_url(),
          { 'id': $( this ).data('assignment-id'),
             'order_uuid': ticket_order_id(),
             'reseating': true,
          }, function( response, status ) {
            e_reference = '[data-assignment-id='+response['id']+']'

            if ((response['status'] == 'available') || (response['status'] == 'releasing'))  {
              update_seating_attributes(e_reference, response['status'])
              ticket_class_id = response['ticket_class_id']
              //data_key = (response['status']=='unavailable')? 'unavailable' : response['id']+','+response['status'];
              data_key = response['id'] + ',' + response['status']
              console.log('status = ' + response['status'])
              console.log(response)
              $("#updated-seat-list").text(response['current_seat_assignments'])
              num_tix = parseInt(response['ticket_count'])
              if (num_tix == parseInt($("#number-of-tickets").text())) {
                $("#finalize-seating").removeClass("disabled")
              } else {
                $("#finalize-seating").addClass("disabled")
              }
              
            }
          });
          break;
        
    };

  });


  $("#finalize-seating").click(function() {
    if (!$(this).hasClass("disabled")) {
      $.post(commit_reseating_url(),
        { 'order_uuid': ticket_order_id()
      }, function(response, status) {
        console.log('response is ' + response['status'])
        if (response['status'] == 'success') {
          $("#seating-config").data('finalized','true')
          $('#change-seats').foundation('close')
          console.log("success")
          setTimeout(function () {
            $("#seatinglist").text(response['current_seat_assignments'])
          }, 800)

        } else {
          console.log("failure")
          alert(response['message'] || 'Unable to finalize seating')
        }
      });
    }
  });

  $(document).on('closed.zf.reveal', '[data-reveal]', function () {
    $.post(rollback_reseating_url(),
      { 'order_uuid': ticket_order_id()
      }, function(response, status) {
      });
  });

});


