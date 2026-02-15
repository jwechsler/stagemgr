Feature: Box office users and administrators can release held seats
  As a box office user or administrator
  I want to release all held seats for a performance
  So that seats are available for sale when needed

  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists

  @javascript
  Scenario: Box office users can see and use the release button in datatable
    Given I am a box office user
    And I am logged in
    And the performance "PROD01A" has 3 held seats without orders
    When I go to the admin production detail page for "Production One"
    Then I should see "Release Held Seats" in the datatable for performance "PROD01A"
    When I follow "Release Held Seats" in the datatable for performance "PROD01A" and confirm
    Then I should see "Released 3 held seats"
    And the performance "PROD01A" should have 0 held seats without orders

  @javascript
  Scenario: Administrators can see and use the release button in datatable
    Given I am an Administrator
    And I am logged in
    And the performance "PROD01A" has 2 held seats without orders
    When I go to the admin production detail page for "Production One"
    Then I should see "Release Held Seats" in the datatable for performance "PROD01A"
    When I follow "Release Held Seats" in the datatable for performance "PROD01A" and confirm
    Then I should see "Released 2 held seats"

  @javascript
  Scenario: Theater users cannot see the release button in datatable
    Given I am a theater user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    Then I should not see "Release Held Seats" in the datatable for performance "PROD01A"

  @javascript
  Scenario: Only orphaned held seats are released from datatable
    Given I am a box office user
    And I am logged in
    And the performance "PROD01A" has 2 held seats without orders
    And the performance "PROD01A" has 2 held seats with a valid HOLD order
    And the performance "PROD01A" has 1 assigned seat
    When I go to the admin production detail page for "Production One"
    And I follow "Release Held Seats" in the datatable for performance "PROD01A" and confirm
    Then I should see "Released 2 held seats"
    And the performance "PROD01A" should have 0 held seats without orders
    And the performance "PROD01A" should have 2 held seats with valid orders
    And the performance "PROD01A" should have 1 assigned seat

  @javascript
  Scenario: Release button works when there are no held seats
    Given I am a box office user
    And I am logged in
    When I go to the admin production detail page for "Production One"
    And I follow "Release Held Seats" in the datatable for performance "PROD01A" and confirm
    Then I should see "Released 0 held seats"

  Scenario: Button does not appear for general admission productions
    Given I am a box office user
    And I am logged in
    And a general admission production "GA Production" exists
    And a performance "GA01" exists for production "GA Production"
    When I go to the admin production detail page for "GA Production"
    Then I should not see "Release Held Seats"
