// Defaults for every rails-jquery-autocomplete input. The gem initialises a
// jQuery UI autocomplete with delay 0 and no request de-duplication, which
// let a held key or a stuck event loop fire one server request per keystroke
// repeat (2026-11-06: 203 identical offer-code searches in 19 s tripped the
// per-IP throttle for the whole box office). Here every input gets a 250 ms
// debounce, and an identical search (same term, same linked field values)
// within 2 s is answered from the previous response instead of the server.
//
// An input that sets its own `delay` attribute keeps it.
//
// On a cache hit the gem's `railsAutocomplete.source` custom event is not
// fired (the gem fires it only after a fetch). Nothing in
// app/assets/javascripts listens for it; only `railsAutocomplete.select` has
// listeners (admin/orders_common.js), and select is unaffected.
(function($) {
  'use strict';

  var DELAY_MS = 250;
  var REPEAT_WINDOW_MS = 2000;

  $(document).on('railsAutocomplete.init', 'input[data-autocomplete]', function() {
    var $input = $(this);
    var widget = $input.autocomplete('instance');
    if (!widget || $input.data('autocomplete-defaults-applied')) return;
    $input.data('autocomplete-defaults-applied', true);

    if (!$input.attr('delay')) $input.autocomplete('option', 'delay', DELAY_MS);

    // The gem's source reads this.element[0], so it must run with the widget
    // as `this`.
    var original = widget.options.source;
    var last = null; // { key, data, at }

    $input.autocomplete('option', 'source', function(request, response) {
      var key = JSON.stringify([request.term, linkedFieldValues($input)]);
      var now = Date.now();
      if (last && last.key === key && now - last.at < REPEAT_WINDOW_MS) {
        response(last.data);
        return;
      }
      original.call(widget, request, function(data) {
        last = { key: key, data: data, at: Date.now() };
        response(data);
      });
    });
  });

  // The gem sends linked field values (data-autocomplete-fields, a JSON map
  // of name to selector) with each request, so they are part of the key.
  function linkedFieldValues($input) {
    var fields = $input.attr('data-autocomplete-fields');
    if (!fields) return null;
    var out = {};
    $.each(JSON.parse(fields), function(name, selector) { out[name] = $(selector).val(); });
    return out;
  }
})(jQuery);
