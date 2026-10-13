// Multi-select production picker for the admin reports page (rendered by
// shared/components/_production_multi_picker). Selected productions become
// hidden <field>[] inputs inside the picker's table; an empty selection
// leaves the report unfiltered. Group suggestions (season / theater /
// festival / tag) resolve server-side and add every member production.
//
// Mirrors offer_picker.js, but forwards the ProductionSearch `scope` into
// GroupedTypeahead.attachMulti (grouped_typeahead.js already threads scope
// into both the search and resolve requests). Ids in the optional
// data-exclude-field hidden fields (e.g. a page's single target picker) are
// left out of the suggestions, as are the productions already chosen.
//
// After every add or remove the wrapper fires a `change` event (bubbling to
// the enclosing form), as theater_multi_picker.js does; the search box's own
// change events are stopped because its text is not a filter.
(function($) {
  'use strict';

  function ProductionMultiPicker($wrap) {
    var field      = $wrap.data('field');
    var $input     = $wrap.find('.production-multi-picker-input');
    var $table     = $wrap.find('.production-multi-picker-table');
    var $removeAll = $wrap.find('.production-multi-picker-remove-all');
    var excludeField = $wrap.data('exclude-field');

    function idsIn($fields) {
      return $fields.map(function() {
        return parseInt($(this).val(), 10) || null;
      }).get();
    }

    function selectedIds() {
      return idsIn($table.find('input[type="hidden"]'));
    }

    function excludedIds() {
      return excludeField ? selectedIds().concat(idsIn($(excludeField))) : selectedIds();
    }

    function refreshChrome() {
      var any = selectedIds().length > 0;
      $table.toggle(any);
      $removeAll.toggle(any);
    }

    function changed() {
      refreshChrome();
      $wrap.trigger('change');
    }

    function addProduction(item) {
      if (!item.id || selectedIds().indexOf(item.id) !== -1) return;
      $('<tr>')
        .append($('<td>').text(item.label))
        .append($('<td class="text-right">')
          .append($('<a href="#" class="production-multi-picker-remove alert">remove</a>'))
          .append($('<input type="hidden">').attr('name', field + '[]').val(item.id)))
        .appendTo($table.find('tbody'));
    }

    GroupedTypeahead.attachMulti($input, {
      searchUrl: $wrap.data('search-url'),
      resolveUrl: $wrap.data('resolve-url'),
      scope: $wrap.data('scope'),
      getExcludedIds: excludedIds,
      onItem: addProduction,
      afterChange: changed
    });

    $input.on('change', function(e) { e.stopPropagation(); });

    $wrap.on('click', '.production-multi-picker-remove', function(e) {
      e.preventDefault();
      $(this).closest('tr').remove();
      changed();
    });

    $removeAll.on('click', function(e) {
      e.preventDefault();
      $table.find('tbody').empty();
      changed();
    });

    refreshChrome();
  }

  $(document).ready(function() {
    $('[data-production-multi-picker]').each(function() {
      new ProductionMultiPicker($(this));
    });
  });
})(jQuery);
