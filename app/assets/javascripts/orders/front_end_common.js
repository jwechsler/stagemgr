// todo -- setup observer to enable button once required fields filled in.  Something like...?

/*
$(function() {
  // Find the button that we want to disable
  var button = $('input.[type=submit]');
  // Disable it!
  button.disabled = true;

  // Find the field that is required:
  var required_fields = new Array($('ticket_order_address_attributes_first_name'),
                                 $('ticket_order_address_attributes_last_name'),
                                 $('ticket_order_address_attributes_email'),
                                 $('ticket_order_address_attributes_line1'),
                                 $('ticket_order_address_attributes_city'),
                                 $('ticket_order_address_attributes_state'),
                                 $('ticket_order_address_attributes_zipcode')
    );

  $(required_fields).bind('keyup',function() {
    var filled_in = true;
    required_fields.each(function(entry) {
      filled_in = (entry.val != "")
    })
    button.disabled = !filled_in
  })
  // Set up an observer to monitor this field

});

*/
