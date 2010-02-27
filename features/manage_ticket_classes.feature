Feature: A box office worker can create ticket classes associated with a production.  Ticket classes manage pricing rules for a production.
  In order to create ticket clases to attach performances and ticket classes to
  As a Box Office user
  I want to create / edit and delete ticket classes records

Scenario: There is a ticket classes link on the Productions Page
  Given I am a Box Office user
    and I am visiting the production detail page
    and there is at least one ticket class defined for the production
   Then there is a link to the ticket classes listing page.
   
Scenario: There is a New Ticket Class link on the Productions page
  Given I am a Box Office user
   and I am visiting the production detail page
   and there are no ticket classes defined for the production
  Then there is a link to the new ticket class page.

Scenario: There is a New Ticket Class link on the Ticket Classes Listing Page
  Given I am a Box Office user
    and I am visiting the ticket classes listing page for a production
  Then there is a "New Ticket Class link" that takes the user to the New Ticket Class page
  
Scenario: The box office user can add a ticket class to a production
  Given the user is a box office user
    and they are visiting the New ticket class page
   Then they can enter the following fields:
     Class Code (4 character abbreviation)
     Class name (varchar)
     Ticket price 
     Ticketing fee
     Visible on Web (boolean)
     Type (Fixed, Donation, Timed)
     Minutes before show (integer)

Scenario: The box office user can see a listing of ticket classes associated with a production
  Given I am a box office user
    and I am visiting the ticket classes listing page
   Then I can see a list of ticket classes defined 
    that displays Class Code, Class Name, Ticket price, Visible on Web, Type
    and displays the name of the associate production on the top of the page
    
    
Scenario: The box office user return to a production from the ticket classes page
  Given I am a box office user
    and I am visiting the ticket classes listing page
    and I click on the production name
   Then the user returns to the production detail page.
