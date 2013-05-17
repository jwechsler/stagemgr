//= require jquery
//= require jquery-ui
//= require jquery_ujs
//= require_this


$(function(){
   $("input[type=date]").datepicker({ dateFormat: 'yy-mm-dd' });
  $('.performance_list a[data-type=html]').on('ajax:success', function(event, data, status, xhr) {
    $('#production_detail').html(data)
  });

  $('a.ajax_target_loader').click(function() {

    $("#" + $(this).attr('target_id')).load($(this).attr('fetch_url'), "id=" + $(this).attr('fetch_id'))

  })
})

$(function() {
  $('form a.add_child').click(function() {
    var assoc   = $(this).attr('data-association');
    var content = $('#' + assoc + '_fields_template').html();
    var regexp  = new RegExp('new_' + assoc, 'g');
    var new_id  = new Date().getTime();

    $(this).before(content.replace(regexp, new_id));
    $(this).before($("<br/>"))
    return false;
  });

  $('form a.remove_child').live('click', function() {
    var hidden_field = $(this).prev('input[type=hidden]')[0];
    if(hidden_field) {
      hidden_field.value = '1';
    }
    $(this).parents('.fields').hide();
    return false;
  });
});
