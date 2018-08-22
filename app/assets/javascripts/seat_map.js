//= require jquery.imagemapster.min

$(document).ready(function() {

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
            },{
              key: 'available',
              isSelectable: true,
              staticState: false,
              render_select: {
                fillColor: '000000',
                fillOpacity: 0.0
              }
            }]
  };

  $('img.seatingmap').mapster(mapster_options);

  $('#seatingmap').mapster('resize',$('img#seatingmap').width(),$('img#seatingmap').height());

});

