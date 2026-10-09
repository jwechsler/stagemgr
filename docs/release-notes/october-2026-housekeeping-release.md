Hi all,

This update is almost entirely bug fixes, and most of them are about things Stagemgr should have been refusing to do for years and quietly wasn't. Nothing here changes how you sell a ticket. A few things change what happens when you delete something or change a price, so please skim the first two sections.  I did this as a mid-week push because it was about data corruption, which I hate.

---

## Deleting things is now safe (it wasn't)

Looks like poor Josh was trying to search the productions page for King Lear and nothing was working.  So I went looking for why searching for "Kin" in the production picker crashed, and found a production that pointed at a theater that no longer existed (called “Parking”). The theater had been deleted years ago and Stagemgr never checked whether anything depended on it. Pulling on that thread turned up a whole family of safety checks that stopped working when I upgraded Rails a long while back (six years ago). The code still said "don't delete this", but Rails had changed how you say that, so it was being ignored. Bad!

**Now:**

- **Theaters can't be deleted while any order depends on them (via a performance to a production to the theater).**  The page tells you why instead of pretending the delete worked.  
- **A production with no orders** deletes cleanly along with its performances and ticket classes. Before, any performance at all blocked it, which was a workaround for the broken checks.
- **Seat maps in use by a production, or with sold seats, can't be deleted.** This one was the scary one: deleting a seat map used to take every seat assignment on it with it, sold ones included. I confirmed it on a copy of our data, in a sandbox, and “brrrrrr….!”. It never actually happened to us BUT IT COULD HAVE. It now can't.
- **Payment types with payments** can't be deleted either. Before, trying to delete one just crashed.
- **Addresses** that can't be deleted show a message instead of an error page.
- **The "Kin" search crash** is fixed, and the stray production is gone.

I also found that non-admin box office logins had a back door for editing and deleting theaters and productions. That door is bricked up; those live only under Admin now.

Every one of these rules is covered by tests, plus a lint check that fails the build if anyone (including an overexcited AI) writes a safety check the old way again. Geeky details on request.

---

## You can change prices on ticket classes again

**Before:** changing the price on a ticket class that had never sold a single ticket was often refused with a message about existing sales. Around 265 ticket classes were stuck this way, a dozen of them on productions with performances coming up.

**Why:** since 2011, every time the order form was saved, the blank ticket lines for the classes you didn't pick were "removed" by unlinking them from the order rather than deleting them. Over fifteen years that added up to about 368,000 ghost line items floating around with no order, and the price-change check was counting them as sales. The leak itself was plugged a week ago; this update deletes the backlog and makes it impossible for a line item to exist without an order.

**Now:** a ticket class that has genuinely never sold accepts a new price. Classes with real sales are still protected.

---

## Other Bug Fixes

- **Checkmarks and icons showing as empty boxes.** The little checkmarks in the Orders and report tables (and a few other icons) were rendering as hollow squares on the live site. Stagemgr was looking for its icon font at the wrong address. Fixed.
- **Expired sessions on admin pages.** If your login timed out on a venue, seat map, membership or special-feature page, you got an "unexpected error" instead of the login page, and I got an exception email every time it happened. You now land on the login page. My inbox thanks you.
- **Abandoned-order cleanup now says when it can't delete something** instead of skipping it silently.

---

## Behind the scenes

A few things you won't see but that make the app sturdier: production now loads every model at startup instead of on first use (which closes a trap where some payment reports could have varied by which server process answered), the test suite runs once per change instead of twice, and I have a cleaner setup for working on several branches at once. Startup is a hair slower; nothing else changes.

Jeremy
