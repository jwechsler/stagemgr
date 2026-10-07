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
//
// Pass outstandingLabels ({with: '...', without: '...'}) to add the
// All / with / without outstanding filter, right-aligned beside the search
// box. Its value goes to the server as the `outstanding` param (see
// DatatableBase#filter_by_outstanding) and is kept in the saved table state.
function initOfferTable(selector, columns, language, outstandingLabels) {
  var outstanding = '';
  var options = {
    "processing": true,
    "serverSide": true,
    "stateSave": true,
    "ajax": $(selector).data('source'),
    "pagingType": 'full_numbers',
    "language": language,
    columns: columns
  };

  if (outstandingLabels) {
    $.extend(options, {
      "dom": 'lf<"offer-outstanding-filter">rtip',
      "ajax": {
        url: $(selector).data('source'),
        data: function (data) { data.outstanding = outstanding; }
      },
      stateSaveParams: function (settings, data) { data.outstanding = outstanding; },
      stateLoadParams: function (settings, data) { outstanding = data.outstanding || ''; }
    });
  }

  var table = $(selector).DataTable(options);
  if (outstandingLabels) {
    buildOutstandingFilter(table, outstandingLabels, function () { return outstanding; },
                           function (value) { outstanding = value; });
  }
}

// Renders the outstanding filter's button group into the table's toolbar slot
// and redraws the table when a choice is made.
function buildOutstandingFilter(table, labels, getValue, setValue) {
  var choices = [['', 'All'], ['with', labels.with], ['without', labels.without]];
  var $group = $('<div class="button-group tiny" role="group" aria-label="Filter by outstanding"></div>');

  choices.forEach(function (choice) {
    $('<button type="button" class="button"></button>')
      .attr('data-outstanding', choice[0])
      .text(choice[1])
      .appendTo($group);
  });

  function markSelected() {
    $group.find('button').each(function () {
      var isSelected = $(this).attr('data-outstanding') === getValue();
      $(this).toggleClass('hollow', !isSelected).attr('aria-pressed', isSelected ? 'true' : 'false');
    });
  }

  $group.on('click', 'button', function () {
    setValue($(this).attr('data-outstanding'));
    markSelected();
    table.draw();
  });

  markSelected();
  $(table.table().container()).find('div.offer-outstanding-filter').append($group);
}
