// Multi-select offer picker for the admin reports page (rendered by
// shared/components/_offer_picker). Selected offers become hidden
// <field>[] inputs inside the picker's table; an empty selection leaves
// the report unfiltered. Group suggestions (tag / theater) resolve
// server-side and add every member offer.
(function($) {
  'use strict';

  function OfferPicker($wrap) {
    var field      = $wrap.data('field');
    var groupField = $wrap.data('group-field');
    var $input     = $wrap.find('.offer-picker-input');
    var $table     = $wrap.find('.offer-picker-table');
    var $removeAll = $wrap.find('.offer-picker-remove-all');

    function selectedGroups() {
      return $table.find('input.offer-picker-group').map(function() {
        return $(this).val();
      }).get();
    }

    // A dynamic group stays one row, listed above the offers; the page's
    // controller expands it when the form runs.
    function addDynamicGroup(item) {
      if (!groupField || selectedGroups().indexOf(item.group_key) !== -1) return;
      $('<tr class="offer-picker-dynamic">')
        .append($('<td>').append($('<strong>').text(item.label)))
        .append($('<td class="text-right">')
          .append($('<a href="#" class="offer-picker-remove alert">remove</a>'))
          .append($('<input type="hidden" class="offer-picker-group">')
            .attr('name', groupField + '[]').val(item.group_key)))
        .prependTo($table.find('tbody'));
    }

    function selectedIds() {
      return $table.find('input[type="hidden"]').not('.offer-picker-group').map(function() {
        return parseInt($(this).val(), 10) || null;
      }).get();
    }

    function refreshChrome() {
      var any = $table.find('tbody tr').length > 0;
      $table.toggle(any);
      $removeAll.toggle(any);
    }

    // Redraw after a user change and tell the page the selection changed
    // ('offer-picker:changed' on the picker element, bubbling to the form).
    function selectionChanged() {
      refreshChrome();
      $wrap.trigger('offer-picker:changed');
    }

    function addOffer(item) {
      if (!item.id || selectedIds().indexOf(item.id) !== -1) return;
      // An inactive offer (analysis scope) shows its bare name plus a badge
      // instead of the "(Inactive)" suffix its suggestion label carries.
      var isInactive = item.active === false;
      var $name = $('<td>').text(isInactive ? item.name : item.label);
      if (isInactive) {
        $name.append(' ').append($('<span class="label secondary">').text('Inactive'));
      }
      var $row = $('<tr>')
        .toggleClass('offer-picker-inactive', isInactive)
        .append($name)
        .append($('<td class="text-right">')
          .append($('<a href="#" class="offer-picker-remove alert">remove</a>'))
          .append($('<input type="hidden">').attr('name', field + '[]').val(item.id)));
      // Keep inactive offers below the active ones.
      var $firstInactive = $table.find('tbody tr.offer-picker-inactive').first();
      if (!isInactive && $firstInactive.length) {
        $row.insertBefore($firstInactive);
      } else {
        $row.appendTo($table.find('tbody'));
      }
    }

    GroupedTypeahead.attachMulti($input, {
      searchUrl: $wrap.data('search-url'),
      resolveUrl: $wrap.data('resolve-url'),
      scope: $wrap.data('scope'),
      getExcludedIds: selectedIds,
      onItem: addOffer,
      onDynamicGroup: addDynamicGroup,
      afterChange: selectionChanged
    });

    $wrap.on('click', '.offer-picker-remove', function(e) {
      e.preventDefault();
      $(this).closest('tr').remove();
      selectionChanged();
    });

    refreshChrome();

    $removeAll.on('click', function(e) {
      e.preventDefault();
      $table.find('tbody').empty();
      selectionChanged();
    });
  }

  $(document).ready(function() {
    $('[data-offer-picker]').each(function() {
      new OfferPicker($(this));
    });
  });
})(jQuery);
