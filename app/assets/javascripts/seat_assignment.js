//= require seat_map

$(document).ready(function() {
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

  function update_mapster_attributes(e_reference, data_key, status) {
    // console.log('setting key to ' + data_key + ', status = ' + status)
    if (data_key != '') {
      $( e_reference ).attr('data-key', data_key)
      $( e_reference ).data('key',data_key)
    }
    $( e_reference ).attr('data-status', status)
    $( e_reference ).data('status',status)
    if (status == 'available') {
      $( e_reference).mapster('deselect')
    }
    // $( e_reference ).mapster('highlight', false)
  }

  function update_selected() {
    $("#seatingmap area[data-status='assigned']").mapster('select')
  }

  function update_informational() {
    selected_seats = []
    seating_count=0
    $( "#seatingmap area[data-status='assigned']" ).each (function() {
        selected_seats.push($(this).data('location'))
        seating_count++
      });

    $( '.seatinglist').text(selected_seats.sort().join(','))
    max_assigned = max_assignable()
    if (seating_count < max_assigned) {
      console.log("display reminder")
      $('#seating-remaining').text((max_assigned - seating_count) + " of " + max_assigned + " remaining")
      $('#submit-control').addClass('hide')
    } else {
      $('#seating-remaining').text("Seating complete!")
      $('#submit-control').removeClass('hide')
    }
    update_seating_submit_button(seating_count == max_assigned)

    update_selected()
  }

  $('.seating-required').removeClass('hide')
  $('.seating-not-required').addClass('hide')

  is_fully_seated = (count_assigned() >= max_assignable())

  console.log(count_assigned())
  console.log(max_assignable())
  update_seating_submit_button(is_fully_seated)

  mapster_options = {
    mapKey: 'data-key',
    fillColor: '00ff00',
    fillOpacity: 0.5,

    areas: [{
              key: 'assigned',
              staticState: true,


            },{
              key: 'unavailable',
              staticState: true,
              isSelectable: false,
              render_highlight: {
                fillColor: '000000',
                fillOpacity: 0
              },
              render_select: {
                fillColor: '222222',
                fillOpacity: 0.3
              }
            },
            {
              key: 'available',
              isSelectable: true,
              staticState: true,
              render_select: {
                fillColor: '000000',
                fillOpacity: 0.0
              }

            }]
  };

  update_informational();
  // assign keys


  $('#seatingmap area').click( function(e) {

    starting_status = $(this).data('status')
    data_key = $(this).data('key')
    starting_assigned = count_assigned()

    e_reference = '[data-assignment-id=' + $(this).data('assignment-id') + ']'
    seating_count = 0
    max_allowed = max_assignable()
    if (starting_status == 'available') {
      if (starting_assigned < max_allowed) {
        $.post( reserve_url(),
          { 'id': $( this ).data('assignment-id'),
             'order_id': ticket_order_id()
          }, function( response, status ) {

            e_reference = '[data-assignment-id='+response['id']+']'
            data_key = response['id']+','+response['status']
            $.each(response['unavailable'], function(index,value) {
              $('[data-assignment-id='+value+']').attr('data-key','unavailable')
              $('[data-assignment-id='+value+']').attr('data-status','unavailable')
              $('[data-assignment-id='+value+']').data('key','unavailable')
              $('[data-assignment-id='+value+']').data('status','unavailable')

            });
            $('img.seatingmap').mapster('rebind',mapster_options);
            //console.log($('[data-assignment-id='+response['id']+']').data());
            if (response['status'] == 'unavailable') {
              alert("Sorry, that seat is no longer available")
            } else if (response['status'] == 'assigned') {
              update_mapster_attributes(e_reference, data_key, response['status'])
              // $( e_reference ).mapster('set', true, data_key)
            } else {
              $( e_reference ).mapster('deselect')
            }

            update_informational()
          });
        } else {
          $( e_reference ).mapster('deselect')
        }
    } else if (starting_status == 'assigned') {
      $.post( release_url(),
        { 'id': $( this ).data('assignment-id'),
           'order_id': ticket_order_id()
        }, function( response, status ) {
          e_reference = '[data-assignment-id='+response['id']+']'
          data_key = (response['status']=='unavailable')? 'unavailable' : response['id']+','+response['status'];
          update_mapster_attributes(e_reference, data_key, response['status'])
          $( e_reference ).mapster('deselect')
          // $( e_reference ).mapster('set',true,data_key)
          // $( e_reference ).mapster('highlight', false)
          // $('img.seatingmap').mapster('unbind')
          // $('img.seatingmap').mapster('rebind',mapster_options);
          update_informational()

      });
    }


    $( e_reference ).mapster('highlight', false)



  });
  seating_still_required = $("#seating-status").text().trim()
  if (seating_still_required == 'false') {
    $("#seating-block").removeClass('hide')
    $("#seating-control").addClass('hide')
  } else {
    $("#seating-block").addClass('hide')
    $("#seating-control").removeClass('hide')
  }
  $("#seating-control").on('click', function() {
    $("#seating-block").removeClass('hide')
    $("#seating-control").addClass('hide')
  });

});




