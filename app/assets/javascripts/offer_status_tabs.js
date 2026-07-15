// Shared behavior for the admin offer index pages (Special Offers,
// Membership Offers, Flex Pass Offers), which all present an Active and an
// Inactive tab (#offer-status-tabs) with one server-side datatable per panel.
//
// Call from the page's ready handler BEFORE initializing the datatables, so a
// restored tab is already visible when its table lays out:
//
//   initOfferStatusTabs('flex_pass_offers');
//   initOfferTable('#active_flex_pass_offer_listing', columns, language);
//   initOfferTable('#inactive_flex_pass_offer_listing', columns, language);

// Restores the last tab the user selected on this page (sticky for the
// browser session, via sessionStorage) and records each subsequent selection.
// Also recalculates datatable column widths whenever a tab is revealed,
// because tables in an initially-hidden panel lay out with zero-width columns.
// Relies on Foundation already being initialized: application.js registers
// its $(document).foundation() ready handler before any per-page script runs.
function initOfferStatusTabs(pageKey) {
  var storageKey = 'offer-status-tab:' + pageKey;
  var $tabs = $('#offer-status-tabs');

  var savedPanel = null;
  try {
    savedPanel = sessionStorage.getItem(storageKey);
  } catch (e) { /* storage unavailable (e.g. blocked by browser settings) */ }
  if (savedPanel && $tabs.find('a[href="' + savedPanel + '"]').length && !$(savedPanel).hasClass('is-active')) {
    $tabs.foundation('selectTab', savedPanel);
  }

  $tabs.on('change.zf.tabs', function (event, $tab) {
    var href = $tab.find('a').attr('href');
    if (href) {
      try {
        sessionStorage.setItem(storageKey, href);
      } catch (e) { /* storage unavailable */ }
    }
    $.fn.dataTable.tables({visible: true, api: true}).columns.adjust().responsive.recalc();
  });
}

// Standard server-side datatable configuration shared by the offer index
// tables. Column definitions and language quirks stay with each page.
function initOfferTable(selector, columns, language) {
  $(selector).dataTable({
    "processing": true,
    "serverSide": true,
    "stateSave": true,
    "ajax": $(selector).data('source'),
    "pagingType": 'full_numbers',
    "language": language,
    columns: columns
  });
}
