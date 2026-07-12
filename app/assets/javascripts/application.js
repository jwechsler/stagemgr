//= require chartkick
//= require Chart.bundle
//= require jquery
//= require jquery-ui
//= require jquery_ujs
//= require datatables
//= require datatables_responsive_defaults
//= require what-input/dist/what-input
//= require foundation-sites/dist/js/foundation
//= require jquery.dataTables.yadcf
//= require utility
//= require activestorage
//= require cocoon
//= require jquery-ui/widgets/autocomplete
//= require autocomplete-rails
//= require grouped_typeahead
//= require production_picker
//= require production_multi_picker
//= require offer_picker
//= require tagify
//= require theater_tags
//= require credit_card_track_parser
//= require jquery.creditCardValidator
//= require chartkick
//= require Chart.bundle
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

  $('.disabled').click(function(e){
    return false;
  });
});


$(document).ready(function(){
    $(".fader").hide(0).fadeIn('fast')
});

$(function(){ $(document).foundation(); });
