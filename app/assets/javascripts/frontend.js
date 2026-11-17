// JavaScript for public pages: the counterpart of frontend.css. Every public
// layout (layouts/standalone, or a house's site wrapper) includes this bundle
// before `yield :js`.
//
// It carries only the libraries public pages share:
// - jquery_ujs: the order forms' data-disable-with on submit.
// - Foundation (Reveal) and reveal_confirm: the seat picker's #ticket-modal
//   and its notices (revealAlert). seat_map.js initialises the modal itself;
//   nothing here calls $(document).foundation().
//
// Page scripts (orders_common, seat_assignment) arrive through `yield :js` and
// contain only their own code.
//
// The bundle carries its own jQuery because a site wrapper may load a
// different jQuery or none. jquery_ujs and Foundation attach to this copy,
// which becomes the global $ / jQuery for the page scripts that follow.
//
//= require jquery
//= require jquery_ujs
//= require foundation-sites/dist/js/foundation
//= require reveal_confirm
