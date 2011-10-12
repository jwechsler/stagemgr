/**
 * Require address, city, state, zip, email for front-end orders
 * User: jeremyw
 * Date: 10/6/11
 * Time: 9:23 AM
 * To change this template use File | Settings | File Templates.
 */


 document.observe('form:button_disable', function (event) {
  // Find the button that we want to disable
  var button = $('ticket_order_submit');
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

  // Set up an observer to monitor this field
  required_fields.forEach(function (required_field) {
    new Field.Observer(required_field, 0.3, function() {
        // If field == '' then button disabled = true
        button.disabled = ($F(required_field) === '');
        });
  });
});