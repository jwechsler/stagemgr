
function show_payment_form(payment_type) {
  $('#payment_forms').children('div').each(function() {
    $(this).hide();
  });
  switch (payment_type) {
    case "1":
      $('#credit_card_payment_form').show();
      break;
    case "3":
      $('#flex_pass_payment_form').show();
      break;
    case "5":
      $('#membership_payment_form').show();
      console.log("find membership")
      break;
    case "6":
      $('#check_payment_form').show();
      break;
  }
  show_pass_donation_card_form(payment_type);
}

var DONATION_FIELDS = '#ticket_order_additional_donation, #ticket_order_additional_donation_for_other';

function donation_total() {
  var total = 0;
  $(DONATION_FIELDS).each(function() {
    var amount = parseFloat($(this).val());
    if (amount > 0) {
      total += amount;
    }
  });
  return total;
}

// A pass covers only the tickets, so a donation made with one is charged to a
// card: show the card form, captioned, while a donation is entered.
// #payment_forms lists the passes on offer (orders/_billing_form).
function show_pass_donation_card_form(payment_type) {
  var pass_names = $('#payment_forms').data('pass-names') || {};
  var pass_name = pass_names[payment_type];
  var donation = donation_total();
  var show = pass_name !== undefined && donation > 0;
  $('#pass-donation-caption').prop('hidden', !show);
  if (show) {
    var formatter = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
    $('#pass-donation-caption .pass-name').text(pass_name);
    $('#pass-donation-caption .donation-amount').text(formatter.format(donation));
    $('#credit_card_payment_form').show();
  }
}

function show_proper_admin_payment_form() {
  show_payment_form($("[name*='payment_type_id']").val());
}

function show_proper_payment_form() {
  show_payment_form($("[name*='payment_type_id']:checked").val());
}

function setup_payment_form() {
  show_proper_payment_form();
  jQuery(document).ready(function($) {
    $(".payment_type_choice input").change(function() {
      show_proper_payment_form();
    });
    $(DONATION_FIELDS).on('input change', function() {
      show_proper_payment_form();
    });
  });
}

