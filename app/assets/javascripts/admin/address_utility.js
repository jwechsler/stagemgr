/*
  address_utility.js -- Address lookup and utility functions
*/

function autofillAddress(order_type, event, ui) {
  $("#"+order_type+"_address_attributes_email").val(ui.item.email)
  $("#"+order_type+"_address_attributes_line1").val(ui.item.line1)
  $("#"+order_type+"_address_attributes_line2").val(ui.item.line2)
  $("#"+order_type+"_address_attributes_city").val(ui.item.city)
  $("#"+order_type+"_address_attributes_state").val(ui.item.state)
  $("#"+order_type+"_address_attributes_zipcode").val(ui.item.zipcode)
  $("#"+order_type+"_address_attributes_phone").val(ui.item.phone)
  $("#"+order_type+"_member_code").val(ui.item.member_code)
  t = $("#quick-lookup #attended_shows").html(ui.item.attended)

  $("#quick-lookup #tags").html(ui.item.tags);
  $("#purchaser-name").text(' [' + ui.item.value + ']');
  $('div#full-name-input-column').addClass('small-10');
  $('div#full-name-input-column').removeClass('small-12');
  $('div#full-name-clear-column').removeClass('hide');

  if (ui.item.member_code) {
    $("#"+order_type+"_payment_type_id option").filter(function() {
      //may want to use $.trim in here
      return $(this).text() == 'Membership';
    }).prop('selected', true);
    show_proper_payment_form()
  }
  $('#quick-lookup').removeClass('hide');
}
