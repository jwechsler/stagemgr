Feature: Box office users can email performance attendees
  As a box office user or administrator
  I want to send custom email messages to all ticket holders for a performance
  So that I can communicate important updates to attendees

  Background:
    Given a sample theater exists
    And a test performance "TEST01A" exists
    And the performance "TEST01A" has 3 processed orders with valid email addresses

  @javascript
  Scenario: Box office users can see the Email Attendees button in datatable
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    Then I should see "Email Attendees" in the datatable for performance "TEST01A"

  @javascript
  Scenario: Administrators can see the Email Attendees button in datatable
    Given I am an Administrator
    And I am logged in
    When I go to the admin production detail page for "Production One"
    Then I should see "Email Attendees" in the datatable for performance "TEST01A"

  @javascript
  Scenario: Theater users cannot see the Email Attendees button in datatable
    Given I am a theater user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    Then I should not see "Email Attendees" in the datatable for performance "TEST01A"

  @javascript
  Scenario: Clicking Email Attendees opens modal with recipient count
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    Then I should see the email attendees modal
    And I should see "3" recipients in the modal

  @javascript
  Scenario: Modal displays pre-filled subject with production name and date
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    Then the subject field should contain "Important update regarding Production One"

  @javascript
  Scenario: Form validation requires all fields
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I click "Send Email to 3 Recipients"
    Then I should see "Please fill in all required fields"
    And the modal should remain open

  @javascript
  Scenario: Successfully sending broadcast email to attendees
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I select "Theater Wit Box Office" from "From Address"
    And I fill in "Message Body" with "Important venue change notification"
    And I click "Send Email to 3 Recipients" and confirm
    Then I should see "Email queued for 3 recipients"
    And a performance broadcast should be created for performance "TEST01A"
    And 3 outreach tasks should be created for the broadcast

  @javascript
  Scenario: Confirmation dialog shows recipient count
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I select "Theater Wit Box Office" from "From Address"
    And I fill in "Message Body" with "Test message"
    And I click "Send Email to 3 Recipients"
    Then I should see a confirmation dialog asking about sending to "3 recipients"

  @javascript
  Scenario: Canceling confirmation dialog keeps modal open
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I select "Theater Wit Box Office" from "From Address"
    And I fill in "Message Body" with "Test message"
    And I click "Send Email to 3 Recipients" and cancel
    Then the modal should remain open
    And no performance broadcast should be created

  @javascript
  Scenario: Performance with no eligible recipients shows zero count
    Given I am a box office user
    And I am logged in
    And a performance "TEST02A" exists for production "Production One"
    And the performance "TEST02A" has no eligible orders
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST02A"
    Then I should see "0" recipients in the modal
    And the send button should be disabled

  @javascript
  Scenario: Only eligible orders receive broadcast emails
    Given I am a box office user
    And I am logged in
    And the performance "TEST01A" has 2 processed orders with valid email addresses
    And the performance "TEST01A" has 1 canceled order
    And the performance "TEST01A" has 1 order without an email address
    And the performance "TEST01A" has 1 order with a placeholder address
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    Then I should see "2" recipients in the modal

  @javascript
  Scenario: From address dropdown includes box office and current user email
    Given I am a box office user with email "boxoffice@example.com"
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    Then the from address dropdown should include "Theater Wit Box Office"
    And the from address dropdown should include "boxoffice@example.com"

  @javascript
  Scenario: Cancel button closes modal without sending
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I select "Theater Wit Box Office" from "From Address"
    And I fill in "Message Body" with "Test message"
    And I click "Cancel"
    Then the modal should close
    And no performance broadcast should be created

  @javascript
  Scenario: Close button (X) closes modal without sending
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I fill in "Message Body" with "Test message"
    And I click the close button
    Then the modal should close
    And no performance broadcast should be created

  @javascript
  Scenario: Markdown formatting is supported in message body
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I select "Theater Wit Box Office" from "From Address"
    And I fill in "Message Body" with "**Important:** Show starts at 7pm"
    And I click "Send Email to 3 Recipients" and confirm
    Then I should see "Email queued for 3 recipients"
    And the broadcast body should contain markdown formatting

  @javascript
  Scenario: Multiple broadcasts can be sent for the same performance
    Given I am a box office user
    And I am logged in
    And a performance broadcast exists for performance "TEST01A"
    When I go to the admin production detail page for "Production One"
    And I follow "Email Attendees" in the datatable for performance "TEST01A"
    And I select "Theater Wit Box Office" from "From Address"
    And I fill in "Message Body" with "Second broadcast message"
    And I click "Send Email to 3 Recipients" and confirm
    Then I should see "Email queued for 3 recipients"
    And 2 performance broadcasts should exist for performance "TEST01A"
