# Feature: FlexPass Patron Report

Request: We want to add a report to stagemgr that the box office can use to pull a list of flexpass orders between two dates (inclusive). The report pulls FlexPassOrders and offers the following fields:

flexpass order number, patron name, email, phone, the flexpass code, when it expires, and how many admission are currently remaining on that flexpass, Y or N on whether the flexpass has been fulfilled.

The report should be displayable ("Show") from the report screen or "Download" as a file with background generation.

Follow the patterns already in the reports controller and report tasks for building reports and offering the specified functionality.
