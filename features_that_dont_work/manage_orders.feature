Tim, I have no idea where to add/append these functional descriptions, so I’m just doing it here…

The box office user should be able to manage orders as well as enter them.

When the user clicks on “Box Office Order” they should be presented with a screen with two tabs.

Option 1: Place a new order (this takes them to the already existing order placement page.

Option 2: Manage Orders

If the user manages orders, they are presented with a screen that has a filter control at the top, and the filter results below. The filter control is a multi-field control where each text field maps to the column of data presented beneath it. There is a filter control for every column besides order total

The columns are: Order number, Production Code, Performance Code, Purchaser Name, Order Total, Order Status, Last-4.

The production and performance codes filters are typeaheads that work the same as they do in the order entry screen. The Order status is autocompleting for all valid order statuses. The other fields are text fields that the user can search. Searches occur whenever the user leaves a filter field. The searches are automatically wildcarded for completion on (Production/Performance code or Name). The values in the filter fields are sticky by browser (they are cookie-based and are the default values when the user returns to the page).

Clicking on an order number lets you view/edit the order.

Viewing / Editing an order:

Order States. The order state determines whether or not the order can be edited or just viewed.

“Hold”. If the box office puts an order on hold it stays there until released. The order can be edited.

“Web.” If a box office order is in “Web” state it will be released by the system in 8 minutes or changed. The order cannot be edited.

“New” The default state for an order, but transient. The operator must hold or process an order to save it.

“Processed” The order has been processed for payment through the box office (cash, checks) or authorize.net (credit cards). Once an order has been processed, it cannot be edited unless it is refunded or exchanged.

“Refunded” The order can be refunded if it was initially processed. If the order was a credit card order, a refund is sent through authorize.net. All transaction details (transaction ids with authorize.net) must be marked. You must have the “refund order” privilege to do this.

“Exchanged” The order has been exchanged. The new order number is recorded along with this status. We will look at ticket exchanges in a separate story.

“Fulfilled” Once an order has been processed, it can be fulfilled. this is a manual state that reflects the reservation has been mailed/filed/etc. by the box office rep. This is the only field/value that is editable for processed orders.