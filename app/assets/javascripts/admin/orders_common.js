//= require utility
//= require orders/payments
//= require admin/address_utility
//= require admin/ticket_orders/CardReader
//= require credit_card_track_parser
//= require_self

function setup_admin_payment_form() {
  $('#payment_forms').children('div').each(function() {
    $(this).hide()

  });
  switch ($('.payment_type_choice select option:selected').text()) {
    case 'Credit Card':
    case '':
      $('#credit_card_payment_form').show();
      break;
    case 'Cash':
      $('#cash_payment_form').show();
      break;
    case 'FlexPass':
      $('#flex_pass_payment_form').show();
      break;
    case 'Membership':
      $('#membership_payment_form').show();
      break;
    case 'Check':
      $('#check_payment_form').show();
      break;
  }

}

jQuery.fn.extend({
    disable: function(state) {
        return this.each(function() {
            this.disabled = state;
        });
    }
});


jQuery(document).ready(function($) {


  setup_admin_payment_form();
  $(".payment_type_choice select").change(function() {
     setup_admin_payment_form();
   });

  $('#disassociate-address').on('click', function() {
      $('#linked_to_address_id').val('');
      $("#quick-lookup #tags").html('');
      $("#quick-lookup #attended_shows").html('');
      $('div#full-name-input-column').addClass('small-12');
      $('div#full-name-input-column').removeClass('small-10');
      $('div#full-name-clear-column').addClass('hide');
    });

  //$('input[type="submit"]).addClass('disabled');

  $('input[type="submit"].order-submit-button, button').disable(true);
  set_button_state_for_autocompletes();
  $('body').on('click', 'button.disabled', function(event) {
      event.preventDefault();
  });

  $('#admin_ticket_order_form').each(function() {

    $.fn.setup_code_input = function() {

      $(this).on('railsAutocomplete.select',function(event,ui) {
        set_button_state_for_autocompletes();
        price = this.id.replace('ticket_class_code','price_override')
        price_field = $('#'+price);
        price_field.val(Number(ui.item.ticket_price).toFixed(2));

        recalculate_row_total('ticket_order',$(this).parents('.line_item'));
      });
    }

    $("input.price").blur(function(event,ui) {
      recalculate_row_total('ticket_order',$(this).parents('.line_item'));
    });

    $.fn.setup_recalculate_row = function() {
      $(this).on('blur',function() {
        set_button_state_for_autocompletes();
        recalculate_row_total('ticket_order',$(this).parents('.line_item'));
      });
    }

    $('#ticket_order_address_attributes_full_name').on("railsAutocomplete.select", function(event,ui) {
      autofillAddress('ticket_order',event,ui);
    });

    $('input.code-input').setup_code_input();

    $('#ticket_line_items').on('cocoon:after-insert', function(e, insertedItem) {
      $(insertedItem).find('input.code-input').setup_code_input();
      $(insertedItem).find('input.ticket_count').setup_recalculate_row();
    });

    $('input.ticket_count,input.price_override').setup_recalculate_row();

  });
      // $.event.trigger({type:"railsAutocomplete.select",message:"hi",time: new Date()});


  $('#admin_membership_order_form').each(function() {

    $('#membership_order_address_attributes_full_name').on("railsAutocomplete.select", function(event,ui) {
      autofillAddress('membership_order',event,ui);
    });

    setup_gift_form('membership_order')

  });

  $('#admin_flex_pass_order_form').each(function() {

    $('#flex_pass_order_address_attributes_full_name').on("railsAutocomplete.select", function(event,ui) {
      autofillAddress('flex_pass_order',event,ui);
    });

  });

  setup_gift_form();

  $('#update_note_control').addClass("hide");

  $('#update_note').click(function() {
    $('#note_control').addClass("hide");
    $('#update_note_control').removeClass('hide');
    return false;
  });

});

jQuery(function () {
    // Create a new reader instance
    var reader = new CardReader();
    
    // Feed it an object to observe (this could also be a textbox)
    reader.observe($(".credit_card_swipe"));

    log.console('monitoring for card swipe')
    // Errback in case of a reading error
    reader.cardError(function () {
        alert("A read error occurred");
    });

    // Callback in case of a successful reading operation
    reader.cardRead(function (value) {
        var data = CreditCardTrackData(value)
        console.log(data);
        // $('.credit_card_swipe').val(value);
        // $('form').submit();
    });
});
