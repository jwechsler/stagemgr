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
  REVEAL_CONFIRM_OVERLAY_SELECTOR = '.reveal-overlay.reveal-dialog-overlay'.freeze
  # The default action (data-reveal-dialog-default) opens focused and is bold.
  REVEAL_CONFIRM_DEFAULT_BUTTONS = {
    accept: REVEAL_CONFIRM_ACCEPT_SELECTOR,
    cancel: REVEAL_CONFIRM_CANCEL_SELECTOR
  }.freeze
  REVEAL_CONFIRM_BOLD_WEIGHT = '700'.freeze
  REVEAL_CONFIRM_NORMAL_WEIGHT = '400'.freeze
  # A viewport point on the overlay, well clear of the centred dialog.
  REVEAL_CONFIRM_OVERLAY_CLICK_POINT = [5, 5].freeze

  # Clicks the confirm button. +accept_label+ checks its text when given.
  def accept_reveal_confirm(text = nil, accept_label: nil)
    answer_reveal_confirm(text) { |dialog| reveal_confirm_accept_button(dialog, accept_label).click }
  end

  # Clicks the Cancel button.
  def dismiss_reveal_confirm(text = nil)
    answer_reveal_confirm(text) { |dialog| dialog.find(REVEAL_CONFIRM_CANCEL_SELECTOR).click }
  end

  # Presses Esc with focus inside the dialog (on its confirm button), which
  # answers it "no".
  def escape_reveal_confirm(text = nil)
    answer_reveal_confirm(text) { |dialog| dialog.find(REVEAL_CONFIRM_ACCEPT_SELECTOR).send_keys(:escape) }
  end

  # Waits for the confirmation to open and returns it, checking its question
  # when +text+ is given.
  def reveal_confirm_dialog(text = nil)
    reveal_dialog(REVEAL_CONFIRM_MODE_SELECTOR, text)
  end

  # Waits for the confirmation (checking its question when +text+ is given)
  # and checks that +action+ (:accept or :cancel) is its default: named in
  # data-reveal-dialog-default, focused, and bold while the other is not.
  def expect_reveal_confirm_default(action, text = nil)
    other = (REVEAL_CONFIRM_DEFAULT_BUTTONS.keys - [action]).first
    dialog = reveal_confirm_dialog(text)
    expect(page.document).to have_css("#{REVEAL_CONFIRM_MODE_SELECTOR}[data-reveal-dialog-default='#{action}']")
    default_button = dialog.find(REVEAL_CONFIRM_DEFAULT_BUTTONS.fetch(action), focused: true)
    other_button = dialog.find(REVEAL_CONFIRM_DEFAULT_BUTTONS.fetch(other))
    expect(default_button.style('font-weight')['font-weight']).to eq(REVEAL_CONFIRM_BOLD_WEIGHT)
    expect(other_button.style('font-weight')['font-weight']).to eq(REVEAL_CONFIRM_NORMAL_WEIGHT)
    dialog
  end

  # Checks the accept button's label on the open confirmation.
  def expect_reveal_confirm_accept_label(label)
    expect(reveal_confirm_dialog.find(REVEAL_CONFIRM_ACCEPT_SELECTOR)).to have_text(label, exact: true)
  end

  # Presses Enter on whatever has focus (the dialog's default action), without
  # focusing a button first.
  def press_enter_on_reveal_confirm(text = nil)
    answer_reveal_confirm(text) { page.send_keys(:enter) }
  end

  # Clicks the overlay outside the dialog, which answers it "no".
  def click_reveal_confirm_overlay(text = nil)
    answer_reveal_confirm(text) do
      expect(page.document).to have_css(REVEAL_CONFIRM_OVERLAY_SELECTOR, visible: true)
      x, y = REVEAL_CONFIRM_OVERLAY_CLICK_POINT
      page.driver.browser.action.move_to_location(x, y).click.perform
    end
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
