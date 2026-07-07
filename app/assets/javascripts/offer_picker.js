// Multi-select offer picker for the admin reports page (rendered by
// shared/components/_offer_picker). Selected offers become hidden
// <field>[] inputs inside the picker's table; an empty selection leaves
// the report unfiltered. Group suggestions (tag / theater) resolve
// server-side and add every member offer.
(function($) {
  'use strict';

  function OfferPicker($wrap) {
    var field      = $wrap.data('field');
    var $input     = $wrap.find('.offer-picker-input');
    var $table     = $wrap.find('.offer-picker-table');
    var $removeAll = $wrap.find('.offer-picker-remove-all');

    function selectedIds() {
      return $table.find('input[type="hidden"]').map(function() {
        return parseInt($(this).val(), 10) || null;
      }).get();
    }

    function refreshChrome() {
      var any = selectedIds().length > 0;
      $table.toggle(any);
      $removeAll.toggle(any);
    }

    function addOffer(item) {
      if (!item.id || selectedIds().indexOf(item.id) !== -1) return;
      $('<tr>')
        .append($('<td>').text(item.label))
        .append($('<td class="text-right">')
          .append($('<a href="#" class="offer-picker-remove alert">remove</a>'))
          .append($('<input type="hidden">').attr('name', field + '[]').val(item.id)))
        .appendTo($table.find('tbody'));
    }

    GroupedTypeahead.attachMulti($input, {
      searchUrl: $wrap.data('search-url'),
      resolveUrl: $wrap.data('resolve-url'),
      getExcludedIds: selectedIds,
      onItem: addOffer,
      afterChange: refreshChrome
    });

    $wrap.on('click', '.offer-picker-remove', function(e) {
      e.preventDefault();
      $(this).closest('tr').remove();
      refreshChrome();
    });

    $removeAll.on('click', function(e) {
      e.preventDefault();
      $table.find('tbody').empty();
      refreshChrome();
    });
  }

  $(document).ready(function() {
    $('[data-offer-picker]').each(function() {
      new OfferPicker($(this));
    });
  });
})(jQuery);
