# The shared dialog (revealConfirm, revealAlert and the Rails data-confirm
# override in reveal_confirm.js) that replaces native window.confirm() and
# window.alert() in app code. Every step that answers it goes through these
# helpers so the dialog's selectors live in one place.
#
# Each helper waits for the dialog to open, checks its message when +text+ is
# given, answers it and waits for it to close. The dialog is appended to
# <body>, outside any modal it was opened over, so it is looked up from the
# document rather than the current `within` scope.
#
# One element serves both kinds; its data-reveal-dialog-mode attribute says
# which is showing. The confirm helpers look for confirm mode only, so an
# alert that reuses the element straight after a confirmation (e.g. an AJAX
# result) counts as the confirmation having closed.
module RevealConfirmHelpers
  REVEAL_CONFIRM_SELECTOR = '#reveal-confirm'.freeze
  REVEAL_CONFIRM_MODE_SELECTOR = "#{REVEAL_CONFIRM_SELECTOR}[data-reveal-dialog-mode='confirm']".freeze
  REVEAL_ALERT_MODE_SELECTOR = "#{REVEAL_CONFIRM_SELECTOR}[data-reveal-dialog-mode='alert']".freeze
  REVEAL_CONFIRM_MESSAGE_SELECTOR = '#reveal-confirm-message'.freeze
  REVEAL_CONFIRM_ACCEPT_SELECTOR = '[data-reveal-confirm-accept]'.freeze
  REVEAL_CONFIRM_CANCEL_SELECTOR = '[data-reveal-confirm-cancel]'.freeze

  # Clicks the confirm button. +accept_label+ checks its text when given.
  def accept_reveal_confirm(text = nil, accept_label: nil)
    answer_reveal_confirm(text) { |dialog| reveal_confirm_accept_button(dialog, accept_label).click }
  end

  # Clicks the Cancel button.
  def dismiss_reveal_confirm(text = nil)
    answer_reveal_confirm(text) { |dialog| dialog.find(REVEAL_CONFIRM_CANCEL_SELECTOR).click }
  end

  # Presses Esc with focus inside the dialog (it opens focused on its confirm
  # button), which answers it "no".
  def escape_reveal_confirm(text = nil)
    answer_reveal_confirm(text) { |dialog| dialog.find(REVEAL_CONFIRM_ACCEPT_SELECTOR).send_keys(:escape) }
  end

  # Waits for the confirmation to open and returns it, checking its question
  # when +text+ is given.
  def reveal_confirm_dialog(text = nil)
    reveal_dialog(REVEAL_CONFIRM_MODE_SELECTOR, text)
  end

  def expect_no_reveal_confirm
    expect(page.document).to have_no_css(REVEAL_CONFIRM_MODE_SELECTOR, visible: true)
  end

  # Waits for the one-button notice (revealAlert), checks its message when
  # +text+ is given, clicks OK, waits for it to close and returns the message.
  def accept_reveal_alert(text = nil)
    dialog = reveal_dialog(REVEAL_ALERT_MODE_SELECTOR, text)
    expect(dialog).to have_no_css(REVEAL_CONFIRM_CANCEL_SELECTOR, visible: true)
    message = dialog.find(REVEAL_CONFIRM_MESSAGE_SELECTOR).text
    dialog.find(REVEAL_CONFIRM_ACCEPT_SELECTOR).click
    expect_no_reveal_alert
    message
  end

  def expect_no_reveal_alert
    expect(page.document).to have_no_css(REVEAL_ALERT_MODE_SELECTOR, visible: true)
  end

  private

  def reveal_dialog(selector, text)
    dialog = page.document.find(selector, visible: true)
    expect(dialog).to have_css(REVEAL_CONFIRM_MESSAGE_SELECTOR, text: text) if text
    dialog
  end

  def reveal_confirm_accept_button(dialog, accept_label)
    button = dialog.find(REVEAL_CONFIRM_ACCEPT_SELECTOR)
    expect(button).to have_text(accept_label, exact: true) if accept_label
    button
  end

  def answer_reveal_confirm(text)
    yield reveal_confirm_dialog(text)
    expect_no_reveal_confirm
  end
end

World(RevealConfirmHelpers)
