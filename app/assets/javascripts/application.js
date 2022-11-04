//= require jquery
//= require jquery-ui
//= require jquery_ujs
//= require datatables
//= require jquery.dataTables.yadcf
//= require foundation
//= require utility
//= require orders_common
//= require activestorage
//= require admin/orders_common
//= require cocoon
//= require jquery-ui/widgets/autocomplete
//= require autocomplete-rails
//= require credit_card_track_parser
//= require jquery.creditCardValidator
//= require_this


$(document).ready(function() {

  
  $("input.date_picker").each(function(input) {
    $(this).datepicker({
      dateFormat: "yy-mm-dd",
      altField: $(this).next()
    })

    // If you use i18n-js you can set the locale like that
    //$(this).datepicker("option", $.datepicker.regional[I18n.currentLocale()]);
  })  
  
  /*
  $('input.time_picker').timepicker({
    step:15,
    minTime:"9:00am",
    maxTime:"11:30pm",
  });
  */

});



$(document).ready(function(){
    $(".fader").hide(0).fadeIn('fast')
});

$(function(){ $(document).foundation(); });
