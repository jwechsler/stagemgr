@javascript
Feature: Box office resends an order's confirmation email
  As a box office user helping a patron who lost their confirmation
  I want Resend Confirmation to ask once and then send the email
  So that the patron gets exactly one new confirmation when I say OK

  # A reserved-seating processed order: its page loads reseating.js, which
  # bundles application.js a second time (jQuery, jquery_ujs and
  # reveal_confirm.js evaluated twice). A plain data-confirm GET link must
  # still follow through after one OK there.
  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted
    And a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    Then the order page loads reseating.js
    And I note how many confirmation emails that order has been sent

  Scenario: Confirming resends the confirmation email
    When I follow "Resend Confirmation" and answer "Resend confirmation email?" with OK
    Then I should see the notice "Confirmation email resent"
    And the resend confirmation question is not showing
    And one confirmation email has been sent for that order

  Scenario: Cancelling leaves the order alone
    When I follow "Resend Confirmation" and answer "Resend confirmation email?" with Cancel
    Then I am still on the admin page for that order
    And I should not see the notice "Confirmation email resent"
    And no confirmation email has been sent for that order

  Scenario: The question opens with OK as the default, so Enter resends
    When I follow "Resend Confirmation"
    Then the confirmation "Resend confirmation email?" defaults to OK
    When I press Enter in the confirmation "Resend confirmation email?"
    Then I should see the notice "Confirmation email resent"
    And one confirmation email has been sent for that order
