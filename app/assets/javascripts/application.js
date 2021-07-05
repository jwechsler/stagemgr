//= require jquery
//= require jquery_ujs
//= require datatables
//= require jquery-ui/widgets/datepicker
//= require foundation
//= require foundation-datetimepicker
//= require jquery.timepicker
//= require nested_form_fields
//= require utility
//= require orders_common
//= require_this


$(function(){ $(document).foundation(); });

$(document).ready(function() {

  $(function() {
    $('.date_picker').datepicker({ dateFormat: 'yy-mm-dd' });
  });

  // $("input.date_picker").fdatetimepicker({
  //   format: 'yyyy-mm-dd',
  //   minView: 2,
  //   pickTime: false
  // })

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

$(document).ready(function(){
    $(".fader").hide(0).fadeIn('fast')
});
