// Shared DataTables Select behaviour, applied to every table that turns
// Select on (the orders list, the flex pass and membership offer lists).
//
// Safari treats a Shift mousedown on table text as "extend the page's text
// selection", and Select's Shift-click range select then never happens
// (Chrome is unaffected). Cancelling that default on cells the table selects
// with leaves the click to Select. Tables in 'api' style (no mouse
// selection) and cells outside the table's select selector are untouched,
// so Shift-click text selection still works everywhere else.
$(document).on('mousedown', 'table.dataTable > tbody > tr > td', function (e) {
  if (!e.shiftKey) {
    return;
  }

  var table = $(this).closest('table')[0];
  if (!$.fn.dataTable.isDataTable(table)) {
    return;
  }

  var api = $(table).DataTable();
  if (!api.select || api.select.style() === 'api') {
    return;
  }

  if ($(this).is(api.select.selector())) {
    e.preventDefault();
  }
});

// A selection lasts until the user changes what they are looking at. With
// server-side processing only the current page's rows exist in the browser:
// after a redraw Select re-selects the rows that come back and silently
// drops the rest, so a new search, filter, sort, page or page size would
// leave a partial selection. Instead, when the request for the new page
// differs from the last one in anything but its draw counter, the whole
// selection is cleared once the page has drawn. A reload of the same view
// (e.g. after Fulfill Selected) keeps it.
//
// These handlers are on document, so they run after Select's own
// table-level preXhr/draw handlers (which re-select the returning rows).
var SELECT_IGNORED_REQUEST_KEYS = ['draw', '_'];

function selectViewKey(data) {
  var view = $.extend({}, data);
  SELECT_IGNORED_REQUEST_KEYS.forEach(function (key) { delete view[key]; });
  return JSON.stringify(view);
}

function usesMouseSelect(settings) {
  var api = new $.fn.dataTable.Api(settings);
  return api.select && api.select.style() !== 'api';
}

$(document).on('preXhr.dt', function (e, settings, data) {
  if (!usesMouseSelect(settings)) {
    return;
  }

  var key = selectViewKey(data);
  settings._selectViewChanged = settings._selectViewKey !== undefined && settings._selectViewKey !== key;
  settings._selectViewKey = key;
});

$(document).on('draw.dt', function (e, settings) {
  if (settings._selectViewChanged) {
    settings._selectViewChanged = false;
    new $.fn.dataTable.Api(settings).rows({ selected: true }).deselect();
  }
});
