//= require application
//= require jquery.imagemapster
//= require foundation

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
  console.log('setting key to ' + data_key)
  console.log('')
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
  $('img.seatingmap').mapster(mapster_options());
  $('#seatingmap').mapster('resize',$('img.seatingmap').width(),$('img.seatingmap').height());
}



