//= require jquery
//= require jquery-ui
//= require jquery_ujs
//= require foundation
//= require foundation/foundation.topbar
//= require foundation-datetimepicker

//= require dataTables/jquery.dataTables
//= require dataTables/jquery.dataTables.foundation
//= require dataTables/extras/dataTables.tableTools.js
//= require utility
//= require orders_common
//= require_this

$(document).foundation();

$(document).ready(function() {
  $("input.date_picker").fdatetimepicker({
    format: 'yyyy-mm-dd',
    minView: 2,
    pickTime: false
  })
  $('input.tidme_picker').fdatetimepicker({
    format: 'H:ii P',
    pickDate: false,
    autoclose: true,
    maxView: 1,
    startView: 1,
    minuteStep: 15,
    showMeridian: true,
  })

  $('input.datetime_picker').fdatetimepicker({
      autoclose: true,
      todayBtn: 'linked',
      format: "mm/dd/yy H:iiP",

      setStartDate: '2000-01-01',
      minuteStep: 15,
      pickerPosition: "bottom-left"

  });

});

$(function(){
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

  $('form a.remove_child').on('click', function() {
    var hidden_field = $(this).prev('input[type=hidden]')[0];
    if(hidden_field) {
      hidden_field.value = '1';
    }
    $(this).parents('.fields').hide();
    return false;
  });
});

$(function(){ $(document).foundation(); });
