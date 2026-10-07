// Shared behavior for the admin offer index pages (Special Offers,
// Membership Offers, Flex Pass Offers), which all present an Active and an
// Inactive tab (#offer-status-tabs) with one server-side datatable per panel.
//
// Call from the page's ready handler BEFORE initializing the datatables, so a
// restored tab is already visible when its table lays out:
//
//   initOfferStatusTabs('flex_pass_offers');
//   initOfferTable('#active_flex_pass_offer_listing', columns, language, {selectable: true});
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
// Options:
//   selectable: true -- rows select as on the orders list: click one,
//     Cmd/Ctrl- or Shift-click for more. The first cell is excluded because
//     Responsive's expand control lives there. Selection survives a reload
//     of the same view because the datatable sends each row's DT_RowId.
//   outstandingLabels: {with: '...', without: '...'} -- adds the
//     All / with / without outstanding filter, on its own row right-aligned
//     above the search box. Its value goes to the server as the
//     `outstanding` param (see DatatableBase#filter_by_outstanding) and is
//     kept in the saved table state.
//   bulkActions: [{text, url, confirm}] -- buttons that act on the selected
//     rows, right-aligned above the table as Fulfill Selected is on the orders
//     list (on a row of their own, below the search box) and enabled only
//     while rows are selected. Each POSTs the selected ids to +url+ (after
//     confirm(count) returns a question the user accepts, when given) and
//     expects {updated, failed: [{name, errors}]} back. Needs selectable.
function initOfferTable(selector, columns, language, tableOptions) {
  var config = tableOptions || {};
  var outstandingLabels = config.outstandingLabels;
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

  if (config.selectable) {
    // Safari Shift-click and clearing on view changes: datatables_select_defaults.js
    options.select = { style: 'os', selector: 'td:not(:first-child)' };
  }

  var bulkActions = config.bulkActions || [];
  // Three rows: the outstanding filter above the length and search controls,
  // then the bulk action buttons on their own row just above the table, so
  // narrowing the list and acting on it stay visually apart.
  options.dom = (outstandingLabels ? '<"offer-outstanding-filter">' : '') + 'lfr' +
                (bulkActions.length ? '<"offer-bulk-actions"B>' : '') + 'tip';
  if (bulkActions.length) {
    options.buttons = bulkActions.map(function (bulkAction) {
      return {
        text: bulkAction.text,
        action: function (e, dt) { runOfferBulkAction(dt, bulkAction); }
      };
    });
  }

  if (outstandingLabels) {
    $.extend(options, {
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
  if (bulkActions.length) {
    // Lets the stylesheet move the buttons below the paging on phones.
    $(table.table().container()).addClass('offer-table--bulk-actions');
    // draw too: rows that leave the page in a server redraw drop out of the
    // selection without a deselect event.
    var updateBulkButtons = function () {
      table.buttons().enable(table.rows({ selected: true }).any());
    };
    table.on('select deselect draw', updateBulkButtons);
    updateBulkButtons();
  }
}

// POSTs the selected rows' ids for one bulk action, reports the outcome above
// the table and redraws every offer table, since changed offers move tabs.
function runOfferBulkAction(table, bulkAction) {
  var ids = table.rows({ selected: true }).ids().toArray();
  if (!ids.length) {
    return;
  }
  if (bulkAction.confirm && !window.confirm(bulkAction.confirm(ids.length))) {
    return;
  }

  table.buttons().disable();
  $.ajax({ url: bulkAction.url, type: 'POST', dataType: 'json', data: { ids: ids } })
    .done(function (result) {
      showOfferBulkResult(table, bulkAction, result);
      $.fn.dataTable.tables({ api: true }).draw(false);
    })
    .fail(function () {
      showOfferBulkResult(table, bulkAction, null);
      table.buttons().enable();
    });
}

// Fills (creating on first use) a status callout above the table. Text only:
// offer names are user-entered.
function showOfferBulkResult(table, bulkAction, result) {
  var $container = $(table.table().container());
  var $callout = $container.prev('.offer-bulk-result');
  if (!$callout.length) {
    $callout = $('<div class="callout small offer-bulk-result" role="status"></div>').insertBefore($container);
  }

  $callout.removeClass('success warning alert').empty();
  if (!result) {
    $callout.addClass('alert').text(bulkAction.text + ' failed. Please reload the page and try again.');
    return;
  }

  var noun = result.updated === 1 ? ' offer' : ' offers';
  $callout.addClass(result.failed.length ? 'warning' : 'success')
          .append($('<p></p>').text(bulkAction.text + ': ' + result.updated + noun + ' updated.'));
  result.failed.forEach(function (failure) {
    $callout.append($('<p></p>').text('Not changed: ' + failure.name + ' (' + failure.errors + ')'));
  });
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
