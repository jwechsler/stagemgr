// Multi-select theater picker (rendered by
// shared/components/_theater_multi_picker). Selected theaters become hidden
// <field>[] inputs inside the picker's table; an empty selection means all
// theaters. Tag group suggestions carry their member theaters inline, so
// picking one adds every member without a resolve request.
//
// Mirrors production_multi_picker.js. After every add or remove the wrapper
// fires a `change` event (bubbling to the enclosing form), so pages that
// react to form changes see edits to the theater set too; the search box's
// own change events are stopped because its text is not a filter.
(function($) {
  'use strict';

  function TheaterMultiPicker($wrap) {
    var field      = $wrap.data('field');
    var $input     = $wrap.find('.theater-multi-picker-input');
    var $table     = $wrap.find('.theater-multi-picker-table');
    var $removeAll = $wrap.find('.theater-multi-picker-remove-all');

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

    function changed() {
      refreshChrome();
      $wrap.trigger('change');
    }

    function addTheater(item) {
      if (!item.id || selectedIds().indexOf(item.id) !== -1) return;
      $('<tr>')
        .append($('<td>').text(item.label))
        .append($('<td class="text-right">')
          .append($('<a href="#" class="theater-multi-picker-remove alert">remove</a>'))
          .append($('<input type="hidden">').attr('name', field + '[]').val(item.id)))
        .appendTo($table.find('tbody'));
    }

    function inlineMembers(group) {
      if (!group.theaters) return null;
      return group.theaters.map(function(t) { return { id: t.id, label: t.name }; });
    }

    GroupedTypeahead.attachMulti($input, {
      searchUrl: $wrap.data('search-url'),
      getExcludedIds: selectedIds,
      groupMembers: inlineMembers,
      onItem: addTheater,
      afterChange: changed
    });

    $input.on('change', function(e) { e.stopPropagation(); });

    $wrap.on('click', '.theater-multi-picker-remove', function(e) {
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
    $('[data-theater-multi-picker]').each(function() {
      new TheaterMultiPicker($(this));
    });
  });
})(jQuery);
