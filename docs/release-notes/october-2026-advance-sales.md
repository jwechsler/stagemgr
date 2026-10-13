Hi all,

This one is mostly a new analysis page I've wanted for a long time: how far ahead of a show people actually buy, and what that says about whether to extend a run. Alongside it, the donation ask on the checkout page is now something theaters can write yourselves instead of something baked into the code, and the pass-plus-donation bug that bit us last week is fixed (that part has been live since the weekend). Nothing here changes how you sell a ticket.

---

## Advance Sales: how far ahead do people buy?

**Why:** every time we've talked about extending a run, the question underneath has been "is this show slow, or is this audience just a late-buying audience?" and we've answered it from memory. I wanted the numbers.

**Now:** Admin > Analysis has an **Advance Sales** tab. Pick seasons and theaters, choose whether to compare by season, by theater or by production, and it draws one line per group: the share of that group's final sales that was already in hand 60 days out, 30 days out, a week out, and so on down to the day of the show. Under the chart, a table shows how much landed in each window (same day, 1–2 days, 3–6, 7–13, 14–29, 30+). Below that, one panel per production breaks the run into weeks, with performances added after opening flagged so you can see how an extension week sold against the original run.

A few things I learned from it on our own data, so you know it's worth opening:

- **We buy earlier than we used to.** Same-day sales were about 38% of everything in 2016 and are around 21% now.
- **Companies differ a lot.** Remy Bumppo's audience buys about 27 days out on average; Theater Wit's, about 10.
- **Extension weeks are walk-up weeks.** Weeks added after opening run roughly 40% same-day, against about 25% in an opening week. An extension leans on word of mouth, not the advance.

Things to know when you read it:

- **Seasons still playing are marked "in progress"** and drawn dashed. A performance that hasn't happened yet only has its early buyers so far, so an unfinished season always looks like it buys further ahead than it will. Compare finished seasons for a fair read.
- **Only Active performances count.** Private and inactive ones are left out everywhere on the page.
- **Passes vs single tickets.** Tickets bought with a pass tied to a company or festival (the subscription kind) are drawn as a separate line from single tickets. Memberships and the building-wide passes count as single tickets.
- **An exchanged ticket keeps its original purchase date.** Moving someone to Thursday doesn't change when they decided to buy.
- **Northlight is out by default.** Their sales are keyed in by us after the fact, so the dates mean nothing for this; there's a new "Sales recorded externally" tick box on the theater page for that, and a checkbox on the analysis if you want them in anyway.

**Also: a Pace column on the production page.** Each upcoming performance now shows a projection of where it's heading, e.g. **~50 (48% of capacity)**, worked out from how much of a final house that theater typically has in hand this many days out. It says "Too early" when there's not enough history yet to say anything useful. It's a projection from typical behaviour, not a forecast: a good review or a snowstorm moves a show off the curve.

Full write-up is in the manual under Analysis > Advance Sales.

---

## The Analysis page is now one tab per analysis

**Before:** Rate of Sales, Ticket Revenue and Audience hid behind an "Analysis Type" dropdown on one form, and each result page was a dead end: to change a comparison show you went back to the form and started over.

**Now:** Rate of Sales, Ticket Revenue, Audience, Advance Sales and Pass Sales are tabs across the top of Analysis. Every tab works the same way: your selections sit at the top of the page, the results appear below, and you can change any selection and run again without leaving the page. Each run has its own address, so you can bookmark a comparison or send someone a link to it. If a bookmarked show or theater isn't available to you, the page says so and runs on the rest. Theater users attached to a single theater don't see a theater picker at all; the analysis just uses theirs.

---

## You can write the donation appeal now

**Before:** the "Yes! I love Theater Wit, please add a contribution" wording on the checkout page was hard-coded, with the company's name dropped in. Changing it meant a code change.

**Now:** each theater's admin page has a **Default appeal** that shows on its own orders, and the default theater has a **Secondary appeal** that appears alongside a visiting company's ask on their orders (not on co-productions, which show only the co-producer's). Both take the same formatting as production messages, with `{{theater}}` and `{{company}}` filling in names. Leave them blank and patrons see exactly what they see today, so nothing changes until someone edits it.

---

## Donations on pass-paid orders (already live)

[Name], a member, added a $15 donation to Shattered Globe on a membership-paid order, and the donation silently vanished: the system tried to pay the donation with the membership, which of course can't pay for a donation, and the error was written into the order's notes instead of telling anyone. It turned out a pass plus a donation had *never* been chargeable, because the checkout hid the card fields the moment a pass was chosen.

Now the card fields stay up when a pass is picked and a donation is entered, with a line explaining the pass covers the tickets and the card covers the gift; the order won't go through without a card. And errors in that step reach me properly instead of hiding in notes. While testing it I found that a member who had to fix a rejected order (wrong email, say) was quietly switched back to paying by card on the retry. Also fixed.

---

## Behind the scenes

Changes now gather on a release branch and go out as a batch like this one, with hotfixes going straight to the live site in between. I've also set the test suite to run on a fixed clock so it stops failing late in the evening when Chicago and UTC disagree about what day it is. Geeky details on request.

Jeremy
