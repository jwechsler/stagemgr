@javascript
Feature: Autocomplete defaults
  As a box office user
  I want autocomplete fields to wait for me to stop typing and to reuse a repeated search
  So that a held key cannot flood the server and trip the request throttle

  Background:
    Given a general admission production "Autocomplete Show" exists
    And a performance "GA01A" exists for production "Autocomplete Show"
    And I am an administrator
    And I am logged in
    And I visit the new admin ticket order page

  Scenario: The performance code field is debounced and replays an identical search
    When I focus the performance code field
    Then the performance code autocomplete delay should be 250
    When I search the performance code field for "GA01"
    Then the performance code menu should list "GA01A"
    And the performance code autocomplete should have requested the server for "GA01"
    When I note how many performance code autocomplete requests have been made
    And I close the performance code menu
    And I repeat the performance code search for "GA01"
    Then the performance code menu should list "GA01A"
    And the performance code autocomplete should have made no further requests
