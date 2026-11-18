Hi all,

This one changes something you'll see all over the admin side: the little "Are you sure?" boxes. I wanted them to look the same everywhere, and when I went looking I found that about twenty buttons that were supposed to ask before doing something hadn't been asking at all. There's one change for ticket buyers too: wide seat maps finally get room on the ticket page because of things like Dead Outlaw coming up…

Basically, this is a pile of backend changes to fix confirmation dialogs for testing reasons and a few modifications for seat maps to get ready for our co-pro.  What you should look for are any dialogs that don’t behave like you think they should.

————————

## Buttons that should have asked now ask (they didn't)

**Before:** a lot of our Destroy links, plus **Split Order**, **Cancel Order**, **Resend Confirmation** and **Print** on the reports, were written to ask "Are you sure?" first. A Rails upgrade sort of five years ago quietly changed how that question has to be entered in the code, and from then on those buttons just went ahead and did the thing. One click, no question. Bad!

**Now:** they all ask. If a button you've been clicking for years suddenly wants to know if you're sure, that's this, and it's on purpose.

**For anything that deletes, cancels or splits, the safe answer is the default.** Cancel is in bold and is where the cursor sits, so hitting Enter by reflex backs out and does nothing. That covers every Destroy link, Cancel Order, Split Order and Refund to Donation. To go ahead you have to click the other button deliberately. Questions that aren't destructive (Resend Confirmation, Place Order) still default to OK.

————————

## One look for every question and notice

**Before:** confirmations and notices were whatever your browser felt like drawing. Different in Safari and Chrome and titled with the web address.

**Now:** they're all the same small white box, with the question, a Cancel and an OK, and the default in bold. Esc or a click outside the box means no. The public order pages get the same box when a seat has just been taken.

————————

## Change Seating keeps up

Two fixes on the **Change Seating** window for reserved-seating orders:

* **There's now an X in the corner.** Closing the window always cancelled the change in progress, but the only way to do it was Esc or clicking off to the side. Now it's also a button.
* **The seat map is right the second time.** If you cancelled a change, or finished one, and then opened Change Seating again without reloading the page, the map still showed the seats as they'd been when the page first loaded. It now matches what was actually saved, every time.

⠀
————————

## You can add a seat map again (you couldn't)

**Before:** adding a seat map, or replacing the picture on an existing one, crashed with an error page. Every time. The Rails upgrade changed when an uploaded file actually lands on the server, and the code that measures the picture was looking for it too early, with a tool we don't have installed. [WHO HIT IT / WHICH MAP]

**Now:** it saves. If the file you pick isn't a picture we can read, the form tells you so and keeps what you typed.

Two more things on seat maps while I was in there:

* **The seat spreadsheet import tells you what it did.** It used to crash if a column was missing, and it quietly threw away any row it didn't like. Worse, a seat number of "abc" was saved as seat 0. Now a file with a missing column is refused with a message and nothing changes. Otherwise you get a count of the seats imported and a list of the rows it skipped, by line number, with the reason for each.
* **You can fix a seat's row and number in the editor.** They could only be set when the seat was first added. There's now a **Row** box, which applies to every seat you have selected, and a **Number** box for one seat at a time. Neither one changes the seat's label.

————————

## Wide seat maps get the whole page

**Before:** on the public order page the seat map always sat in the right-hand half, beside the list of selected seats. That suits our tall maps. A wide one got squeezed into half the page and the seats came out tiny. This is preperation work for Dead Outlaw.

**Now:** a map that is wider than it is tall runs the full width of the page, with Selected Seats underneath it. Tall maps are right where they've always been. There's nothing to set: it goes by the shape of the picture you upload.

Maps uploaded as PNG files also get a thin outline, so the edge of the room doesn't dissolve into the page.

————————

## Behind the scenes

The browser's own pop-ups can't be clicked by our automated tests, which is a big part of why I did this: every one of these questions can now be opened, read and answered by a test, and each test has to say which question it expects. Along the way I revived the box office order-entry tests, which had been switched off and had quietly gone stale, and cleared out some leftover code on the orders list for buttons that no longer exist.

Any page with a seat map on it was loading our entire admin toolkit a second time. On the public side that meant every ticket buyer picking a seat was downloading the whole back office's worth of code to do it. Each page now loads each thing once, and the public pages get a small kit of their own.

While I was in there I found an **Assign Seats** button on the box office order form, and a whole page behind it, that have been invisible since October 2019. Nobody could reach it, and it would have crashed if they had. Gone.

Login cookies also got a little stricter about which sites are allowed to send them. You shouldn't notice. Geeky details on request.

Jeremy
