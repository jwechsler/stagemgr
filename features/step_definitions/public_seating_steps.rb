# Steps for the public order pages (features/public_reserved_seating.feature,
# features/public_order_scripts.feature), whose layout includes the frontend
# bundle. Seat picking and the latch come from seat_request_latch_steps.rb.

# Bundles no public order page includes.
PUBLIC_FORBIDDEN_BUNDLES = %w[application admin_application public_seating jquery reseating].freeze

Then(/^the order page loads frontend\.js and seat_assignment\.js once each and no admin or application bundle$/) do
  expect(page).to have_css('#seatingmap circle.available[data-assignment-id]')
  bundles = page_script_bundles
  expect(bundles.count('frontend')).to eq(1)
  expect(bundles.count('seat_assignment')).to eq(1)
  expect(bundles).to include('orders_common')
  expect(bundles & PUBLIC_FORBIDDEN_BUNDLES).to eq([])
end

Then(/^the order page loads frontend\.js once and no seat, admin or application bundle$/) do
  expect(page).to have_button('Review Order')
  bundles = page_script_bundles
  expect(bundles.count('frontend')).to eq(1)
  expect(bundles & (PUBLIC_FORBIDDEN_BUNDLES + %w[seat_assignment seat_map])).to eq([])
end

# A bundle that failed to evaluate would leave its globals undefined.
Then(/^the seat picker's libraries are ready on the page's jQuery$/) do
  ready = page.evaluate_script(<<~JS)
    ({
      sameDollar: window.$ === window.jQuery,
      ujs: typeof jQuery.rails === 'object',
      foundation: typeof jQuery.fn.foundation === 'function',
      reveal: !!(window.Foundation && window.Foundation.Reveal),
      revealAlert: typeof window.revealAlert === 'function',
      seating: typeof window.initialize_seating_assignment === 'function'
    })
  JS
  expect(ready).to eq('sameDollar' => true, 'ujs' => true, 'foundation' => true, 'reveal' => true,
                      'revealAlert' => true, 'seating' => true)
end

# Stops the form's real submission (a handler on the form runs before the
# document-level jquery_ujs one), so the page stays put while jquery_ujs
# disables the button for the submit it saw.
When(/^I press "([^"]*)" with the form's submission held back$/) do |label|
  button = find_button(label)
  page.execute_script(<<~JS, button)
    var form = $(arguments[0]).closest('form');
    form.on('submit.heldBack', function(e) { e.preventDefault(); });
  JS
  button.click
end

Then(/^jquery_ujs has disabled the "([^"]*)" button$/) do |label|
  expect(page).to have_button(label, disabled: true)
end

When(/^I release the held-back form and press "([^"]*)"$/) do |label|
  page.execute_script(<<~JS)
    $('form').off('submit.heldBack');
    $('form').each(function() { $.rails.enableFormElements($(this)); });
  JS
  click_button(label)
end

# One #reveal-confirm element serves every revealAlert and revealConfirm.
Then(/^the page has one notice dialog, saying "([^"]*)"$/) do |message|
  expect(page.document).to have_css(RevealConfirmHelpers::REVEAL_ALERT_MODE_SELECTOR, visible: true, text: message)
  expect(page.document).to have_css(RevealConfirmHelpers::REVEAL_CONFIRM_SELECTOR, count: 1, visible: :all)
end
