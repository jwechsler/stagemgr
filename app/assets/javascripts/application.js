//= require jquery
//= require jquery-ui
//= require jquery_ujs
//= require_this

$(function(){
  $('.performance_list a[data-type=html]').on('ajax:success', function(event, data, status, xhr) {
    $('#production_detail').html(data)
  });

  $('a.ajax_target_loader').click(function() {

    $("#" + $(this).attr('target_id')).load($(this).attr('fetch_url'), "id=" + $(this).attr('fetch_id'))

  })
})
