Feature: The box office user has an order management interface that allows them to make reservations, process credit card orders and get basic reports on sales.

Scenario: The box office user has a quick order entry screen.
  Given the box office user navigates to the order entry screen
   Then the user can enter the following line items, in the following order:
     (1) Production Code (typeaheads for all known active productions)
     (2) Performance Code (enabled once production is exited, 
         typeahead for known performances)
     Once the performance code has been entered, the user can see the 
         number of tickets remaining by class for the performance.
     (3) Ticket classes (typeahead field)  
     (4) Quantity and the interface shows the amount (quantity * price).  
         If the ticket class is of type "Donation," then the user can
          enter a donation amount to override the suggested price.
   Then the box office user can add additional line items
    And the box office user can record the purchaser information
    And process the order or put it on hold for later processing.
    A processed order generates a fulfillment record associated with the order
      and reduces the quantity of tickets available for the performance.
    A held order reduces the quantity of tickets available for the
      performance.
    A held order can also be moved to processed once funds received.
    The available tickets for a performance cannot drop below 0.
    
Scenario: The box office user needs to refund an order
  Given the box office user navigates to the order detail screen
    and the order is in a "Processed" status
   Then the user can reverse the transaction.  The reversal annotates the
    fulfillment (does not delete it) and annotates the order to "Refunded"
    The tickets are put back into the available pool for that performance.
    
Scenario: The box office user needs to cancel an order
  Given the box office user navigates to the order detail screen
    and the order is in a "Held" status.
   Then the user can cancel the order.  The cancellation annotates the
     order to a "Cancelled" status
     The tickets are put back into the available pool for that performance.
     
Scenario: The box office user can see all performance counts
  Given the box office user navigates to the performance listing screen,
   They can see a list of all performances, filterable by production, theatre
     performance code, and/or upcoming dates
   Each performance is presented in a tabular format showing the production name, date and time, and tickets remaining.
     Clicking on a performance takes you to the quick order entry screen with 
       appropriate fields filled in.

Feature: The end user must be able to purchase a ticket online. These scenarios must be consumable by an external web wrapper via an Ajax call
and follow the external css style sheet.

Scenario: The user can see a schedule of performances.
  Given that the end user has selected a production, a calendar of
    performance times must be presented back.  Each performance time should
    include a "buy tickets" image/link if tickets are available for that 
    performance.  If the performance is sold out, then the image should
    be a "sold out" icon.  If all the remaining tickets are on hold, the 
    user should be presented by a "Call box office" link.

Scenario: The public can purchase tickets for a performance.
  When a user selects a performance, a table of available ticket classes
    (description) and desired quantities is presented.
  As the user enters quantities for tickets, the tickets are placed on hold 
    in the system and a total count and order amount is updated on the screen.
    If there aren't enough tickets available, the user should be advised 
      to call the box office and the requested number of tickets is not placed
      on hold.
  The user can press a buy now button at any time after they have created
    an order for at least one ticket.
  After placing a buy request, the user is promoted for billing address, first 
    and last names and email (all mandatory).  The user is also offered an
    opportunity to sign up for the building mailing list.
  The user can see their final order before pressing confirm.  
  When the user presses confirm, the system processes their credit card 
    (Visa/Mastercard) throgh authorize.net using the box office's merchant
    account.
  If authorized, the user receives a confirmation email, the tickets are taken
    off hold and an order record with fulfillment record is placed in the
    system.
  If non-authorized, or the user does not press the confirm button, the
    tickets remain in the held state for eight minutes, after which the
    reservation expires.  This expiration can be handled by a periodic task
    (preferable) or as a validation step when displaying any order or
    report page.