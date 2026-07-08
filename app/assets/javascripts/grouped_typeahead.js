// Generic grouped typeahead helpers shared by the production picker
// (analysis, reports, imports) and the offer picker (reports).
//
// Suggestion rows are plain items ({id, label, ...}) mixed with group
// entries ({group_key, label}) and an optional back row ({picker_back}).
// attachMulti wires a bare text input as a multi-select source: picking a
// group resolves it server-side and hands each member to opts.onItem.
(function($) {
  'use strict';

  function renderSuggestion(ul, item) {
    var div = $('<div>');
    if (item.picker_back || item.group_key) {
      div.append($('<strong>').css('color', '#1779ba')
        .text((item.group_key ? '▶ ' : '') + item.label));
    } else {
      div.text(item.label);
    }
    return $('<li>').append(div).appendTo(ul);
  }

  // opts: searchUrl, resolveUrl, scope (optional), minLength,
  //       getExcludedIds(), onItem(item), afterChange()
  function attachMulti($input, opts) {
    $input.autocomplete({
      minLength: opts.minLength || 2,
      source: function(request, response) {
        $.getJSON(opts.searchUrl, { q: request.term, scope: opts.scope }, function(data) {
          var excluded = opts.getExcludedIds ? opts.getExcludedIds() : [];
          response(data.filter(function(item) {
            return item.group_key || excluded.indexOf(item.id) === -1;
          }));
        });
      },
      select: function(event, ui) {
        if (ui.item.group_key) {
          $.getJSON(opts.resolveUrl, { group_key: ui.item.group_key, scope: opts.scope },
            function(data) {
              data.forEach(function(item) { opts.onItem(item); });
              if (opts.afterChange) opts.afterChange();
            });
        } else {
          opts.onItem(ui.item);
          if (opts.afterChange) opts.afterChange();
        }
        $(this).val('');
        return false;
      }
    });
    $input.autocomplete('instance')._renderItem = renderSuggestion;
  }

  window.GroupedTypeahead = {
    renderSuggestion: renderSuggestion,
    attachMulti: attachMulti
  };
})(jQuery);
