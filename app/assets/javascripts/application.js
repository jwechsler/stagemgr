//= require jquery
//= require jquery-ui
//= require foundation
//= require foundation/foundation.topbar
//= require foundation-datetimepicker
//= require jquery.timepicker.js
//= require jquery_ujs
//= require autocomplete-rails
//= require dataTables/jquery.dataTables
//= require dataTables/jquery.dataTables.foundation
//= require dataTables/extras/dataTables.tableTools.js
//= require utility
//= require orders_common
//= require_this


$(document).ready(function() {
  $(document).foundation();

  $("input.date_picker").fdatetimepicker({
    format: 'yyyy-mm-dd',
    minView: 2,
    pickTime: false
  })

  $('input.time_picker').timepicker({
    step:15,
    minTime:"9:00am",
    maxTime:"11:30pm",
  });

  $('input.datetime_picker').fdatetimepicker({
      autoclose: true,
      todayBtn: 'linked',
      format: "mm/dd/yy H:iiP",

      setStartDate: '2000-01-01',
      minuteStep: 15,
      pickerPosition: "bottom-left"

  });

});


$(function(){ $(document).foundation(); });
