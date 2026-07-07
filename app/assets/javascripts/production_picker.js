// Shared production typeahead picker (analysis, reports, imports).
//
// Single mode — auto-initializes on [data-production-picker] wrappers
// (rendered by shared/components/_production_picker). Suggestions mix
// individual productions with group entries (season / theater / tag);
// picking a group drills down to just that group's productions and the
// user then picks one. The submitted value is always a single production
// id in the wrapper's hidden .production-picker-id field.
//
// Multi mode — ProductionPicker.attachMulti($input, opts) preserves the
// analysis comparison semantics: picking a group expands it server-side
// and hands each production to opts.onProduction.
//
// Events (triggered on the wrapper): production-picker:selected (with the
// suggestion object) and production-picker:cleared.
(function($) {
  'use strict';

  var BACK_LABEL = '← All productions';

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

  function SinglePicker($wrap) {
    this.$wrap     = $wrap;
    this.$input    = $wrap.find('.production-picker-input');
    this.$id       = $wrap.find('.production-picker-id');
    this.$display  = $wrap.find('.production-picker-display');
    this.$label    = $wrap.find('.production-picker-label');
    this.$error    = $wrap.find('.production-picker-error');
    this.searchUrl = $wrap.data('search-url');
    this.resolveUrl = $wrap.data('resolve-url');
    this.scope     = $wrap.data('scope');
    this.groups    = String($wrap.data('groups')) !== '0';
    this.required  = String($wrap.data('required')) === '1';
    this.excludeField = $wrap.data('exclude-field');
    this.groupItems = null; // non-null => drilled into a group
    this.lastTerm   = '';
    this.init();
  }

  SinglePicker.prototype.excludedIds = function() {
    if (!this.excludeField) return [];
    return $(this.excludeField).map(function() {
      return parseInt($(this).val(), 10) || null;
    }).get();
  };

  SinglePicker.prototype.source = function(request, response) {
    var self = this;
    var excluded = this.excludedIds();
    if (this.groupItems) {
      var term = request.term.toLowerCase();
      var matches = this.groupItems.filter(function(item) {
        return excluded.indexOf(item.id) === -1 &&
               item.label.toLowerCase().indexOf(term) !== -1;
      });
      response([{ picker_back: true, label: BACK_LABEL }].concat(matches));
      return;
    }
    this.lastTerm = request.term;
    $.getJSON(this.searchUrl,
      { q: request.term, scope: this.scope, groups: this.groups ? '1' : '0' },
      function(data) {
        response(data.filter(function(item) {
          return item.group_key || excluded.indexOf(item.id) === -1;
        }));
      });
  };

  SinglePicker.prototype.enterGroup = function(groupKey) {
    var self = this;
    $.getJSON(this.resolveUrl, { group_key: groupKey, scope: this.scope }, function(data) {
      self.groupItems = data;
      self.$input.autocomplete('option', 'minLength', 0);
      self.reopen('');
    });
  };

  SinglePicker.prototype.exitGroup = function() {
    this.groupItems = null;
    this.$input.autocomplete('option', 'minLength', 2);
    this.reopen(this.lastTerm);
  };

  // jQuery UI closes the menu on select; reopen it after the current event
  // settles so drill-down feels like one continuous interaction.
  SinglePicker.prototype.reopen = function(term) {
    var self = this;
    self.$input.val(term);
    setTimeout(function() {
      self.$input.autocomplete('search', term).focus();
    }, 0);
  };

  SinglePicker.prototype.choose = function(item) {
    this.groupItems = null;
    this.$input.autocomplete('option', 'minLength', 2);
    this.$id.val(item.id);
    this.$label.text(item.label);
    this.$display.removeClass('hide');
    this.$input.val('').hide();
    this.$error.hide();
    this.$wrap.trigger('production-picker:selected', item);
  };

  SinglePicker.prototype.clear = function() {
    this.$id.val('');
    this.$display.addClass('hide');
    this.$input.show().val('').focus();
    this.$wrap.trigger('production-picker:cleared');
  };

  SinglePicker.prototype.init = function() {
    var self = this;

    this.$input.autocomplete({
      minLength: 2,
      source: function(request, response) { self.source(request, response); },
      select: function(event, ui) {
        if (ui.item.picker_back) {
          self.exitGroup();
        } else if (ui.item.group_key) {
          self.enterGroup(ui.item.group_key);
        } else {
          self.choose(ui.item);
        }
        return false;
      }
    });
    this.$input.autocomplete('instance')._renderItem = renderSuggestion;

    this.$wrap.on('click', '.production-picker-remove', function(e) {
      e.preventDefault();
      self.clear();
    });

    if (this.required) {
      this.$input.closest('form').on('submit', function(e) {
        if (!self.$id.val()) {
          e.preventDefault();
          self.$error.show();
          self.$input.focus();
          // jquery_ujs disables submit buttons on a deferred timer (13ms);
          // undo that after it runs so the user can retry once they pick.
          var $form = $(this);
          setTimeout(function() {
            if ($.rails && $.rails.enableFormElements) $.rails.enableFormElements($form);
          }, 50);
        }
      });
    }
  };

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
              data.forEach(function(prod) { opts.onProduction(prod); });
              if (opts.afterChange) opts.afterChange();
            });
        } else {
          opts.onProduction(ui.item);
          if (opts.afterChange) opts.afterChange();
        }
        $(this).val('');
        return false;
      }
    });
    $input.autocomplete('instance')._renderItem = renderSuggestion;
  }

  window.ProductionPicker = {
    attachMulti: attachMulti,
    initAll: function() {
      $('[data-production-picker]').each(function() {
        var $wrap = $(this);
        if ($wrap.data('production-picker-initialized')) return;
        $wrap.data('production-picker-initialized', true);
        new SinglePicker($wrap);
      });
    }
  };

  $(document).ready(function() { ProductionPicker.initAll(); });
})(jQuery);
