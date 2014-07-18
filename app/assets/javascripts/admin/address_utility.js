/*
  address_utility.js -- Address lookup and utility functions
*/

function setup_address_autocompletes(order_type) {
  jQuery(document).ready(function($) {
    if ($("#"+order_type+"_address_attributes_id").val()) {

    } else {

      $("#"+order_type+"_address_attributes_full_name").autocomplete({
          delay: 600,
          autoFocus: false,
          source: function(request, response){
            console.log($("#"+order_type+"_address_attributes_full_name").attr('url'));
            $.ajax({
              url: $("#"+order_type+"_address_attributes_full_name").attr('url'),
              datatype:"jsonp",
              data: {
                term: request.term
              },
              success: function( data ) {
                response( $.map( data, function( item ) {
                  item.line1 = nvl(item.line1)
                  item.zipcode = nvl(item.zipcode)
                  return {
                    label: item.full_name + " - "+nvl(item.line1, ", ") + nvl(item.city," ") + nvl(item.zipcode,' ') + nvl(item.email) ,
                    value: item.full_name,
                    email: item.email,
                    line1: item.line1,
                    line2: item.line2,
                    city: item.city,
                    zipcode: item.zipcode,
                    state: item.state,
                    member_code: item.member_code,
                    phone: item.phone,
                    tags: item.tags,
                    attended: item.attended
                  }
                }));
              }
            })
          },
          select: function(event, ui) {
            $("#"+order_type+"_address_attributes_email").val(ui.item.email)
            $("#"+order_type+"_address_attributes_line1").val(ui.item.line1)
            $("#"+order_type+"_address_attributes_line2").val(ui.item.line2)
            $("#"+order_type+"_address_attributes_city").val(ui.item.city)
            $("#"+order_type+"_address_attributes_state").val(ui.item.state)
            $("#"+order_type+"_address_attributes_zipcode").val(ui.item.zipcode)
            $("#"+order_type+"_address_attributes_phone").val(ui.item.phone)
            $("#"+order_type+"_member_code").val(ui.item.member_code)
            t = $("#address_tags_hints")
            if (t.size() == 0) {
              t = $("<p/>", {"class": "inline-hints", "id": "address_tags_hints"})
              $("#"+order_type+"_address_attributes_full_name_input").append(t)
            }
            if (ui.item.attended != "") {
              display_hint = "<b>Saw:</b> <i>" + ui.item.attended + "</i>"
            } else {
              display_hint = ""
            }
            if ((ui.item.tags != "") && (display_hint != "")) {
              display_hint = display_hint + "<p/>"
            }
            t.html(display_hint + ui.item.tags);


            if (ui.item.member_code) {
              $("#"+order_type+"_payment_type_id option").filter(function() {
                //may want to use $.trim in here
                return $(this).text() == 'Membership';
              }).prop('selected', true);
              show_proper_payment_form()
            }
          }
        });
      $("#"+order_type+"_address_attributes_full_name").bind('keypress', function() {
        return event.which != 13;
      });
    }

  });
};

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
