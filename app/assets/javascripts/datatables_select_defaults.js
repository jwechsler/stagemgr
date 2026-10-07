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
