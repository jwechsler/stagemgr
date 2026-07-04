// Shared DataTables Responsive configuration (DRY core).
//
// Per-table code declares intent only, via className on each column:
//   'all'        - always visible, never collapses
//   'min-medium' - visible >= 640px; folds into the child row below that
//   'min-large'  - visible >= 1024px; folds into the child row below that
//   'none'       - always in the child row, never in the table
//   'never'      - never shown anywhere
// Untagged columns fall back to automatic priority-based collapsing.
//
// IMPORTANT: always tag the FIRST column (normally 'all'). The inline expand
// control anchors to the first cell of each row; if the first column is left
// to auto-fit and gets hidden on a narrow screen, the +/- control vanishes
// with it (bit us on iOS where Safari's fit math hid an untagged id column).

// Foundation-aligned Responsive breakpoints: small 0 / medium 640 / large 1024.
// width = max px at which the breakpoint is active (Foundation min - 1).
// NOTE: mutate the existing array in place — Responsive.defaults.breakpoints
// captured a reference to it at load time, so reassigning the property would
// leave every table on the stock desktop/tablet/mobile names and the
// min-medium/min-large classes would silently fall back to auto-fit mode.
var dtBreakpoints = $.fn.dataTable.Responsive.breakpoints;
dtBreakpoints.length = 0;
dtBreakpoints.push(
  { name: 'large',  width: Infinity }, // >= 1024
  { name: 'medium', width: 1023 },     // 640-1023
  { name: 'small',  width: 639 }       // <= 639
);

// Child-row renderer: identical markup to the stock listHidden renderer, but
// skips columns whose value is blank so the details view only lists fields
// that actually hold data (e.g. no empty "Seats" or "Notes" lines).
// A cell counts as blank only when it has no text AND no visual/interactive
// elements — an icon-only actions cell is not blank.
function isBlankCell(html) {
  var $probe = $('<div>').html(html);
  var hasText = $probe.text().replace(/\u00a0/g, ' ').trim() !== '';
  var hasElements = $probe.find('a, img, input, button, select, textarea, svg, i').length > 0;
  return !hasText && !hasElements;
}

function renderHiddenNonBlank(api, rowIdx, columns) {
  var data = $.map(columns, function (col) {
    if (!col.hidden || isBlankCell(col.data)) {
      return '';
    }
    return '<li data-dtr-index="' + col.columnIndex + '" data-dt-row="' + col.rowIndex + '" data-dt-column="' + col.columnIndex + '">' +
        '<span class="dtr-title">' + col.title + '</span> ' +
        '<span class="dtr-data">' + col.data + '</span>' +
      '</li>';
  }).join('');

  return data ?
    $('<ul data-dtr-index="' + rowIdx + '" class="dtr-details"/>').append(data) :
    false;
}

// Column renderer: full email (or the server-rendered link) on medium+,
// a compact mailto: button on small screens. Foundation's visibility classes
// do the breakpoint switching in CSS, so no redraw is needed on resize.
// Server-side search is unaffected — it runs against the raw DB column.
// Usage: {data: 'email', render: $.fn.dataTable.render.emailResponsive()}
$.fn.dataTable.render.emailResponsive = function () {
  return function (data, type) {
    if (type !== 'display' || !data) { return data; }

    // The cell may be plain text or server-rendered HTML (e.g. a link to the
    // admin page); pull the address out of the text either way.
    var email = $('<div>').html(data).text().trim();
    if (email.indexOf('@') === -1) { return data; }

    var $wrap = $('<div>');
    $('<span class="hide-for-small-only">').html(data).appendTo($wrap);
    $('<a class="button tiny dt-email-button show-for-small-only"><i class="fi-mail"></i></a>')
      .attr('href', 'mailto:' + email)
      .attr('aria-label', 'Email ' + email)
      .appendTo($wrap);
    return $wrap.html();
  };
};

// Turn Responsive on everywhere from one place (an options object is truthy,
// so this also enables the extension for every table).
// autoWidth writes content-derived inline pixel widths on the table and each
// th at init; those freeze the layout at its initial size, overriding
// width:100% and forcing horizontal scroll once the viewport shrinks. Disable
// it so columns reflow as Responsive shows/hides them.
$.extend(true, $.fn.dataTable.defaults, {
  responsive: {
    details: {
      renderer: renderHiddenNonBlank
    }
  },
  autoWidth: false
});
