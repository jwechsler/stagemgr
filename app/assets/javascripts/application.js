//= require jquery
//= require jquery-ui
//= require foundation
//= require foundation/foundation.topbar
//= require foundation-datetimepicker
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
  $('input.time_picker').fdatetimepicker({
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


$(function(){ $(document).foundation(); });
