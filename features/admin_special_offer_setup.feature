Feature: Administer Special Offers
  In order to manage special offers
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
      And I follow "Add % Off Offer"
     Then I should see "% Off"
      And I should not see "Buy quantity"
    When I enter a special offer with code "TEST" for 50% off
      And I press "Create Percent off special offer"
     Then a special offer with code "TEST" for 50% off is found
      And I should see "Created new special offer 'TEST'"

  Scenario: Box Office Users can create a Buy X Get Y offer
    Given I am a box office user
      And I am logged in
      And I go to the admin special offers page
      And I follow "Add Buy X Get Y Offer"
     Then I should see "Buy X Get Y"
    When I enter a buy 2 get 1 special offer with code "B2G1"
      And I press "Create Buy x get y special offer"
     Then a special offer called "B2G1" is found
      And I should see "Created new special offer 'B2G1'"

  Scenario: Box Office Users can set day of the week filters
    Given I am a box office user
      And I am logged in
      And a special offer with code "TEST" for 50% off exists
      And I go to the edit page for special offer "TEST"
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

