// Seat assignment for the public reserved-seating order page. Public order
// pages have no `application` bundle (their layout is standalone or a house's
// site wrapper), so this bundle carries the libraries seat_assignment and
// orders_common need: jquery_ujs (Place Order's disable_with), Foundation's
// Reveal (#ticket-modal), reveal_confirm (revealAlert) and utility
// (formatCurrency). Admin pages include seat_assignment or reseating directly,
// on top of the `application` bundle their layout already loads.
//
// The bundle deliberately carries its own jQuery: a house's site wrapper may
// supply a different jQuery version or none, and Foundation and jquery_ujs are
// only known to work on this one. Relying on the wrapper's jQuery instead is a
// possible later cleanup.
//
//= require jquery
//= require jquery_ujs
//= require foundation-sites/dist/js/foundation
//= require reveal_confirm
//= require utility
//= require seat_assignment
//= require_this

$(function(){ $(document).foundation(); });
