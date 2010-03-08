Feature: The theater user can pull a box office report

Scenario: Box office and theater users can pull a sales report
  Given the user is a theater user or a box office user
   Then the user can go to a report builder page.
   They can select any production they have access to.
   They get a report for that production displayed on the screen showing
     Production Code
     Performance code
     Performance date/time
     One column for each ticket class showing tickets sold
     One column for tickets on hold (ie, not Processed)
     One column for tickets remaining for that performance
     One column showing revenue collected for that performance.
  The final row shows totals for that column.
  The report is downloadable in comma-delimited format.
