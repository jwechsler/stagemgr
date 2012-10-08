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
            $.ajax({
              url: $("#"+order_type+"_address_attributes_full_name").attr('autocomplete_url'),
              datatype:"jsonp",
              data: {
                q: request.term
              },
              success: function( data ) {
                response( $.map( data, function( item ) {
                  item.line1 = nvl(item.line1)
                  item.zipcode = nvl(item.zipcode)
                  return {
                    label: item.full_name + " - "+nvl(item.line1, ", ") + nvl(item.city," ") + nvl(item.zipcode,' ') + nvl(item.email),
                    value: item.full_name,
                    email: item.email,
                    line1: item.line1,
                    line2: item.line2,
                    city: item.city,
                    zipcode: item.zipcode,
                    state: item.state,
                    member_code: item.member_code,
                    phone: item.phone
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
            if (ui.item.member_code) {
              $("#"+order_type+"_payment_type").val('Membership')
              show_proper_payment_form(order_type)
            }
          }
        });

      $("#"+order_type+"_address_attributes_full_name").bind('keypress', function() {
        return event.which != 13;
      });
    }

  });
};
