// revealConfirm(message, options) -- a Foundation Reveal stand-in for
// window.confirm(). Returns a Promise that resolves true when the user
// confirms and false on Cancel, the close button, Esc or an overlay click.
//
//   revealConfirm('Process this order?', { confirmText: 'Place Order' })
//     .then(function (confirmed) { if (confirmed) { ... } });
//
// Options: confirmText (default 'OK'), cancelText (default 'Cancel').
//
// One dialog element (#reveal-confirm) is built on first use and reused. It
// opens with multipleOpened so a reveal already open underneath (e.g. the
// email attendees modal) stays open. Esc is handled here rather than by
// Foundation: Foundation binds Esc on window for every open reveal, so its
// handler would close the modal underneath too, and its close() unbinds the
// other modal's Esc handler.
var REVEAL_CONFIRM_ID = 'reveal-confirm';
var REVEAL_CONFIRM_MESSAGE_ID = 'reveal-confirm-message';
var REVEAL_CONFIRM_DEFAULT_CONFIRM_TEXT = 'OK';
var REVEAL_CONFIRM_DEFAULT_CANCEL_TEXT = 'Cancel';
var REVEAL_CONFIRM_ESCAPE_KEYS = ['Escape', 'Esc'];

var revealConfirmState = { $el: null, reveal: null, resolve: null, $returnFocus: null };

function revealConfirmBuild() {
  var $el = $('<div class="reveal tiny"></div>').attr({
    id: REVEAL_CONFIRM_ID,
    'aria-labelledby': REVEAL_CONFIRM_MESSAGE_ID
  });
  $el.append($('<p class="lead"></p>').attr('id', REVEAL_CONFIRM_MESSAGE_ID));
  $el.append(
    $('<div class="text-right"></div>')
      .append($('<button type="button" class="button secondary" data-reveal-confirm-cancel></button>'))
      .append(' ')
      .append($('<button type="button" class="button" data-reveal-confirm-accept></button>'))
  );
  $el.append(
    $('<button type="button" class="close-button" data-reveal-confirm-close aria-label="Close"></button>')
      .append($('<span aria-hidden="true"></span>').text('×'))
  );
  $el.appendTo('body');

  var reveal = new Foundation.Reveal($el, { multipleOpened: true, closeOnEsc: false });
  // Foundation sets role="dialog" in its init; this is a confirmation.
  $el.attr({ role: 'alertdialog', 'aria-modal': 'true' });

  $el.on('click', '[data-reveal-confirm-accept]', function () { revealConfirmSettle(true); });
  $el.on('click', '[data-reveal-confirm-cancel], [data-reveal-confirm-close]', function () {
    revealConfirmSettle(false);
  });
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

function revealConfirm(message, options) {
  var opts = options || {};
  if (!revealConfirmState.$el) { revealConfirmBuild(); }
  var $el = revealConfirmState.$el;

  // A second call while open: the earlier question is answered "no" and the
  // dialog stays open showing the new one.
  if (revealConfirmState.resolve) {
    var previous = revealConfirmState.resolve;
    revealConfirmState.resolve = null;
    previous(false);
  }

  $el.find('#' + REVEAL_CONFIRM_MESSAGE_ID).text(message);
  $el.find('[data-reveal-confirm-accept]').text(opts.confirmText || REVEAL_CONFIRM_DEFAULT_CONFIRM_TEXT);
  $el.find('[data-reveal-confirm-cancel]').text(opts.cancelText || REVEAL_CONFIRM_DEFAULT_CANCEL_TEXT);

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
