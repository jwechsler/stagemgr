// revealConfirm(message, options) -- a Foundation Reveal stand-in for
// window.confirm(). Returns a Promise that resolves true when the user
// confirms and false on Cancel, Esc or an overlay click.
//
//   revealConfirm('Process this order?', { confirmText: 'Place Order' })
//     .then(function (confirmed) { if (confirmed) { ... } });
//
// Options: confirmText (default 'OK'), cancelText (default 'Cancel').
//
// revealAlert(message, options) -- the same dialog as a one-button notice in
// place of window.alert(). Returns a Promise that resolves (undefined) once
// the notice is dismissed by OK, Esc or an overlay click.
// Options: okText (default 'OK').
//
// One dialog element (#reveal-confirm) is built on first use and reused; its
// data-reveal-dialog-mode attribute says which kind is showing ("confirm" or
// "alert"). It opens with multipleOpened so a reveal already open underneath
// (e.g. the email attendees modal) stays open. Esc is handled here rather than
// by Foundation: Foundation binds Esc on window for every open reveal, so its
// handler would close the modal underneath too, and its close() unbinds the
// other modal's Esc handler.
//
// Pages without Foundation's Reveal fall back to the native dialogs (still
// returning Promises).
//
// Rails data-confirm: $.rails.allowAction is replaced (see the bottom of this
// file) so data-confirm links, buttons and forms ask through this dialog.
// data-confirm-accept="Label" sets the accept button's text.
var REVEAL_CONFIRM_ID = 'reveal-confirm';
var REVEAL_CONFIRM_MESSAGE_ID = 'reveal-confirm-message';
var REVEAL_CONFIRM_DEFAULT_CONFIRM_TEXT = 'OK';
var REVEAL_CONFIRM_DEFAULT_CANCEL_TEXT = 'Cancel';
var REVEAL_CONFIRM_ESCAPE_KEYS = ['Escape', 'Esc'];
var REVEAL_DIALOG_MODE_ATTR = 'data-reveal-dialog-mode';
var REVEAL_DIALOG_MODE_CONFIRM = 'confirm';
var REVEAL_DIALOG_MODE_ALERT = 'alert';
// DOM-node properties (see the jquery_ujs section): set while the answered
// action is re-dispatched, and while the element's question is open.
var REVEAL_CONFIRM_UJS_BYPASS_PROP = 'revealConfirmAnswered';
var REVEAL_CONFIRM_UJS_PENDING_PROP = 'revealConfirmPending';
var REVEAL_CONFIRM_UJS_ACCEPT_DATA = 'confirm-accept';

var revealConfirmState = { $el: null, reveal: null, resolve: null, $returnFocus: null };

function revealDialogIsAvailable() {
  return !!(window.Foundation && window.Foundation.Reveal);
}

function revealConfirmBuild() {
  // This file can be evaluated twice on a page (seat_map.js re-requires
  // application.js); drop a dialog built by the earlier copy.
  var $stale = $('#' + REVEAL_CONFIRM_ID);
  $stale.closest('.reveal-overlay').remove();
  $stale.remove();
  var $el = $('<div class="reveal reveal-dialog"></div>').attr({
    id: REVEAL_CONFIRM_ID,
    'aria-labelledby': REVEAL_CONFIRM_MESSAGE_ID
  });
  $el.append($('<p class="reveal-dialog__message"></p>').attr('id', REVEAL_CONFIRM_MESSAGE_ID));
  $el.append(
    $('<div class="reveal-dialog__actions"></div>')
      .append($('<button type="button" class="reveal-dialog__action" data-reveal-confirm-cancel></button>'))
      .append($('<button type="button" class="reveal-dialog__action reveal-dialog__action--accept" ' +
        'data-reveal-confirm-accept></button>'))
  );
  $el.appendTo('body');

  var reveal = new Foundation.Reveal($el, { multipleOpened: true, closeOnEsc: false });
  // Lets _reveal_dialog.scss style the overlay on pages without Foundation's CSS.
  $el.parent('.reveal-overlay').addClass('reveal-dialog-overlay');
  // Foundation sets role="dialog" in its init; this is a confirmation.
  $el.attr({ role: 'alertdialog', 'aria-modal': 'true' });

  $el.on('click', '[data-reveal-confirm-accept]', function () { revealConfirmSettle(true); });
  $el.on('click', '[data-reveal-confirm-cancel]', function () { revealConfirmSettle(false); });
  $el.on('keydown', function (e) {
    if (REVEAL_CONFIRM_ESCAPE_KEYS.indexOf(e.key) === -1) { return; }
    e.preventDefault();
    e.stopPropagation();
    revealConfirmSettle(false);
  });
  $el.on('open.zf.reveal', function () {
    $el.find('[data-reveal-confirm-accept]').trigger('focus');
  });
  // Overlay clicks (and any other close) arrive here. Ignore a late event
  // from an earlier close if the dialog has since been reopened.
  $el.on('closed.zf.reveal', function () {
    if (!reveal.isActive) { revealConfirmSettle(false); }
  });

  revealConfirmState.$el = $el;
  revealConfirmState.reveal = reveal;
}

// Resolves the pending promise once, then closes the dialog.
function revealConfirmSettle(confirmed) {
  var resolve = revealConfirmState.resolve;
  revealConfirmState.resolve = null;
  if (resolve) { resolve(confirmed); }

  if (revealConfirmState.reveal.isActive) {
    revealConfirmState.reveal.close();
    if (revealConfirmState.$returnFocus) { revealConfirmState.$returnFocus.trigger('focus'); }
  }
}

// Shows the dialog in the given mode and resolves with the answer (true only
// for the accept button). A call while it is open answers the earlier
// question "no" (an earlier alert just resolves) and shows the new one.
function revealDialogOpen(message, mode, acceptText, cancelText) {
  if (!revealConfirmState.$el) { revealConfirmBuild(); }
  var $el = revealConfirmState.$el;

  if (revealConfirmState.resolve) {
    var previous = revealConfirmState.resolve;
    revealConfirmState.resolve = null;
    previous(false);
  }

  $el.attr(REVEAL_DIALOG_MODE_ATTR, mode);
  $el.find('#' + REVEAL_CONFIRM_MESSAGE_ID).text(message);
  $el.find('[data-reveal-confirm-accept]').text(acceptText);
  $el.find('[data-reveal-confirm-cancel]')
    .text(cancelText || '')
    .toggle(mode === REVEAL_DIALOG_MODE_CONFIRM);

  return new Promise(function (resolve) {
    revealConfirmState.resolve = resolve;
    if (revealConfirmState.reveal.isActive) {
      $el.find('[data-reveal-confirm-accept]').trigger('focus');
    } else {
      revealConfirmState.$returnFocus = $(document.activeElement);
      revealConfirmState.reveal.open();
    }
  });
}

function revealConfirm(message, options) {
  var opts = options || {};
  if (!revealDialogIsAvailable()) { return Promise.resolve(window.confirm(message)); }

  return revealDialogOpen(
    message,
    REVEAL_DIALOG_MODE_CONFIRM,
    opts.confirmText || REVEAL_CONFIRM_DEFAULT_CONFIRM_TEXT,
    opts.cancelText || REVEAL_CONFIRM_DEFAULT_CANCEL_TEXT
  );
}

function revealAlert(message, options) {
  var opts = options || {};
  if (!revealDialogIsAvailable()) {
    window.alert(message);
    return Promise.resolve();
  }

  return revealDialogOpen(message, REVEAL_DIALOG_MODE_ALERT, opts.okText || REVEAL_CONFIRM_DEFAULT_CONFIRM_TEXT)
    .then(function () { return undefined; });
}

// --- Rails data-confirm (jquery_ujs) ----------------------------------------
//
// jquery_ujs asks synchronously: its click/submit handlers call
// $.rails.allowAction(element) and stop the event when it returns false. The
// replacement fires the same `confirm` event, returns false while the dialog
// is open, then fires `confirm:complete` with the answer. On "yes" it repeats
// the action once with the question bypassed: a native click() for links and
// buttons (jQuery's trigger('click') does not follow an href), a fresh submit
// for a form carrying data-confirm itself.
//
// The bypass and pending markers live on the DOM node, not in jQuery data:
// pages that load seat_map.js evaluate jquery_ujs and this file twice, so two
// jQuery instances (separate data caches) each handle the same click.

function revealConfirmRedispatch($element) {
  var el = $element[0];
  if (!el || !document.body.contains(el)) { return; }

  el[REVEAL_CONFIRM_UJS_BYPASS_PROP] = true;
  try {
    if ($element.is('form')) {
      revealConfirmResubmit(el);
    } else {
      el.click();
    }
  } finally {
    // The re-dispatch runs synchronously, so every handler has seen the
    // flag by now; clear it even if nothing reached allowAction.
    el[REVEAL_CONFIRM_UJS_BYPASS_PROP] = false;
  }
}

// requestSubmit fires the submit event (so jquery_ujs's remote/disable
// handling runs); jQuery's trigger falls back to the native submit().
function revealConfirmResubmit(form) {
  if (typeof form.requestSubmit === 'function') {
    form.requestSubmit();
  } else {
    $(form).trigger('submit');
  }
}

function revealConfirmAllowAction(rails, nativeAllowAction, element) {
  var message = element.data('confirm');
  if (!message) { return true; }

  var el = element[0];
  if (el[REVEAL_CONFIRM_UJS_BYPASS_PROP]) { return true; }
  if (!revealDialogIsAvailable()) { return nativeAllowAction.call(rails, element); }
  // Another jQuery instance's handler has already opened this question.
  if (el[REVEAL_CONFIRM_UJS_PENDING_PROP]) { return false; }
  if (!rails.fire(element, 'confirm')) { return false; }

  el[REVEAL_CONFIRM_UJS_PENDING_PROP] = true;
  revealConfirm(String(message), { confirmText: element.data(REVEAL_CONFIRM_UJS_ACCEPT_DATA) || undefined })
    .then(function (answer) {
      el[REVEAL_CONFIRM_UJS_PENDING_PROP] = false;
      var isAllowed = rails.fire(element, 'confirm:complete', [answer]);
      if (answer && isAllowed) { revealConfirmRedispatch(element); }
    });
  return false;
}

function revealConfirmInstallUjs($) {
  if (!$ || !$.rails || !$.rails.allowAction) { return; }
  var rails = $.rails;
  var nativeAllowAction = rails.allowAction;
  rails.allowAction = function (element) {
    return revealConfirmAllowAction(rails, nativeAllowAction, element);
  };
}

revealConfirmInstallUjs(window.jQuery);
