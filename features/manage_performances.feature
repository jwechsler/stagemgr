Feature: A box office worker can create performances associated with a production.  Performances are 
  scheduled performances of a particular production
  As a Box Office user
  I want to create / edit and delete performances records

Scenario: There is a performances link on the Productions Page
  Given I am a Box Office user
    and I am visiting the production detail page
    and there is at least one performance defined for the production
   Then there is a link to the performance listing page.

Scenario: There is a New Ticket Class link on the Productions page
  Given I am a Box Office user
    and I am visiting the production detail page
    and there are no performances defined for the production
  Then there is a link to the new performance page.

Scenario: There is a New Performance link on the Performance Listing Page
  Given I am a Box Office user
    and I am visiting the performances listing page for a production
  Then there is a "New Performance" that takes the user to the New performance page

Scenario: The box office user can add a performance to a production
  Given the user is a box office user
    and they are visiting the New Performance page
   Then they can enter the following fields:
     Performance Date
     Performance Time
     Status (Active / Inactive) 
     Performance Code (defaults to Production Code + MMDD). This field is unique across ALL performances.
     Associated Ticket Classes
       There is a list of ticket classes (as defined for the production) with a boolean switch on each one
         to detail if tickets of that class are available for this production.  Each class also as a "limit"
         box.  If it's filled in with a number, no more than that number of tickets can be sold for this 
         performance.  Otherwise if blank, tickets up to capacity can be sold.  There should be a checkbox 
         labeled "check all" that will check all of the defined ticket classes.
     
Scenario: The box office user can see a listing of performances associated with a production
  Given I am a box office user
    and I am visiting the performance listing page
   Then I can see a list of performances defined 
    that displays Date, Time, Status for each performance
    and displays the name of the associated production on the top of the page

Scenario: The box office user return to a production from the performance listing page
  Given I am a box office user
    and I am visiting the performance listing page
    and I click on the production name
   Then the user returns to the production detail page.

Scenario: The box office user can delete a performance
  Given I am a box office user
    and I am visiting the performance listing page
    and I click a delete button in the performance performance
   Then the system prompts me for confirmation. If confirmed, the performance is deleted, along with
    it's associated ticket class definitions.

Scenario: The box office user can duplicate a performance
  Given I am a box office user
    and I am visiting the performance listing page
    and I click a "duplicate" button in the performance row
   Then the system takes me to the New Performance Screen, with all the fields except date and time
    duplicated from the source record.  Date and Time should be blank.
    
Scenario: The box office user cannot create duplicate performances
  Given the user tries to save a production with the same date and time as another performance for
    the associated production.
   Then the system displays an alert dialog and will not save the record.

