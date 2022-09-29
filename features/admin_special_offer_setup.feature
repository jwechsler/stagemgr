Feature: Administer Special Offers
  In order manage special offers
  As an box office user
  I want to create and edit special offers
  Background:
    Given a sample theater exists

  Scenario: There is a 'Special Offers' menu link for box office users
    Given I am a box office user
      And I am logged in
      And I go to the home page
     Then "Special Offers" should link to "the admin special offers page"

  Scenario: There is not a 'Special Offers' menu link for non-admins
    Given I am a theater user
      And I am logged in
      And I go to the home page
     Then I should not see "Special Offers"

  Scenario: Box Office Users can create special offers
    Given I am a box office user
      And I am logged in
      And I go to the admin special offers page
      And I follow "Add special offer"
      And I enter a special offer with code "TEST" for 50% off
      And I press "Create Special offer"
     Then a special offer with code "TEST" for 50% off is found
      And I should see "Created new special offer 'TEST'"

  Scenario: Box Office Users can set day of the week filters
    Given I am a box office user
      And I am logged in
      And a special offer with code "TEST" for 50% off exists
      And I go to the edit page for special offer "TEST"
      And I follow "TEST"
      And I check "Thursdays"
      And I check "Fridays"
      And I press "Update Percent off special offer"
      And I go to the edit page for special offer "TEST"
     Then the "Thursdays" checkbox should be checked
      And the "Fridays" checkbox should be checked
      And the "Mondays" checkbox should not be checked
      And the "Tuesdays" checkbox should not be checked
      And the "Wednesdays" checkbox should not be checked
      And the "Saturdays" checkbox should not be checked
      And the "Sundays" checkbox should not be checked

