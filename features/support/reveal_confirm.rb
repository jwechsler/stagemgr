# The shared confirmation dialog (revealConfirm in reveal_confirm.js) that
# replaces native window.confirm() on admin pages. Every step that answers it
# goes through these helpers so the dialog's selectors live in one place.
#
# Each helper waits for the dialog to open, checks its question when +text+ is
# given, answers it and waits for it to close. The dialog is appended to
# <body>, outside any modal it was opened over, so it is looked up from the
# document rather than the current `within` scope.
module RevealConfirmHelpers
  REVEAL_CONFIRM_SELECTOR = '#reveal-confirm'.freeze
  REVEAL_CONFIRM_MESSAGE_SELECTOR = '#reveal-confirm-message'.freeze
  REVEAL_CONFIRM_ACCEPT_SELECTOR = '[data-reveal-confirm-accept]'.freeze
  REVEAL_CONFIRM_CANCEL_SELECTOR = '[data-reveal-confirm-cancel]'.freeze

  # Clicks the confirm button. +accept_label+ checks its text when given.
  def accept_reveal_confirm(text = nil, accept_label: nil)
    answer_reveal_confirm(text) { |dialog| reveal_confirm_accept_button(dialog, accept_label).click }
  end

  # Confirms an action that answers with a native alert, accepting the alert
  # as part of the click (no other browser command may run while it is open)
  # and returning its message.
  def accept_reveal_confirm_and_alert(text = nil, accept_label: nil)
    button = reveal_confirm_accept_button(reveal_confirm_dialog(text), accept_label)
    message = accept_alert { button.click }
    expect_no_reveal_confirm
    message
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

  # Waits for the dialog to open and returns it, checking its question when
  # +text+ is given.
  def reveal_confirm_dialog(text = nil)
    dialog = page.document.find(REVEAL_CONFIRM_SELECTOR, visible: true)
    expect(dialog).to have_css(REVEAL_CONFIRM_MESSAGE_SELECTOR, text: text) if text
    dialog
  end

  def expect_no_reveal_confirm
    expect(page.document).to have_no_css(REVEAL_CONFIRM_SELECTOR, visible: true)
  end

  private

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
