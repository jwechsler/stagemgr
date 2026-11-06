Hi all,

This update is mostly about speed. At the end of October I pulled numbers from the live database and found that five kinds of query were eating close to half its time, most of them doing the same work over and over for no reason. Fixing those turned up two real bugs, one of which has been printing on your tickets. It goes in tonight after the box office closes.

---

## Mine Customer Data works again (it didn't)

**Before:** the Mine Customer Data button crashed on every patron it looked at, swallowed the error, and handed back a list that wasn't one. [WHO HIT IT / WHAT THEY WERE TRYING TO PULL] On top of that, the **Min. Revenue** and **Min. Perf.** boxes were saved with the report and then never used, so even when it ran, everybody qualified.

**Now:** it runs, and both minimums actually filter. Put in $500 and you get the people who spent $500, not the whole database. The help page for it has been rewritten to match what the form really asks and what the spreadsheet really contains.

---

## Patron codes on tickets will look different

The code printed on each ticket starts with what that patron has spent with us over the last 18 months. Except it didn't: the calculation forgot to say *whose* payments, so every single patron got the same number, the whole theater's revenue. [SINCE WHEN, IF YOU KNOW] Bad!

**Now:** it's the patron's own spending on orders they bought. Tickets someone else bought for them as a gift don't count toward theirs. Expect the codes to change from tomorrow on. Nothing else about them changes.

---

## Sales by Performance is faster

[WHO NOTICED / WHAT PROMPTED IT] The Sales by Performance report was looking up every order, and then every ticket on every order, one at a time. Mud Row took 5.9 seconds to produce; it now takes 2.3. The numbers are identical, and I checked.

---

## One thing you might notice

**The Now Playing widgets on the website now refresh every five minutes** instead of on every page view. They were being loaded about 600 times an hour and rebuilt from scratch every time. If you change a production and the widget doesn't show it right away, give it five minutes.

---

## Behind the scenes

House counts were adding up seats one order at a time, about 150,000 tiny queries a day and 17% of the database's time; each performance is now a single query. The advance sales curves were recomputing a seven-second calculation every hour for past seasons that can't change; they now refresh once a night. Merging customers got two indexes so it no longer scans half a million rows. And our hosting provider's database requires every table to have a primary key, which four little linking tables didn't. Adding them turned up a small leak, where fulfilling an order recorded the same attendance again each time. Geeky details on request.

Jeremy
