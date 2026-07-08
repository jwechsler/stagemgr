# Festival Passes & Membership Caps

!!! info "Who uses this?"
    **Box Office Managers** configure festival restrictions on flex pass and membership offers. The rules then apply automatically during checkout and box office sales.

**Navigation:** Passes > Flex Pass Offers / Membership Offers

---

## Restricting a Flex Pass to a Festival

A flex pass offer can be tied to a festival so its tickets redeem only for that festival's shows. On the flex pass offer form, choose the festival in the **Restrict to festival** dropdown (in the **Use Restrictions** fieldset).

![Flex pass offer form with the Festival restriction dropdown](../assets/images/screenshots/festivals-flex-pass-restriction.png)

When a patron redeems a festival-restricted pass for a show outside the festival, the redemption is refused with:

> That FlexPass is only valid for {Festival Name} shows. Please contact our box office for details.

!!! warning "Festival restriction stacks with the other gates"
    The festival gate is **additional** -- it never replaces the pass's existing rules. Theater restrictions, ticket class, expiration, and Maximum Uses Per Production all still apply exactly as before. A pass restricted to both a theater and a festival must satisfy both.

!!! note "Legacy festival passes"
    Before festivals existed, the **Treat as Festival Pass** flag and per-production pass links approximated this behavior. Those settings still work for existing offers and are labeled "(legacy)" on the forms; new offers should use the **Festival** dropdown instead.

## Capping Membership Advance Bookings

A membership offer can limit how many festival tickets a member books **in advance**, across the whole festival, while leaving day-of-show sales to box office discretion. On the membership offer form, set **Festival tickets in advance** (in the **Membership Details** fieldset).

![Membership offer form with the Max festival tickets in advance field](../assets/images/screenshots/festivals-membership-cap.png)

| Value | Behavior |
|-------|----------|
| *(blank)* | No festival cap -- membership tickets for festival shows follow the offer's normal rules. |
| A number *N* | The membership covers at most *N* advance tickets **summed across all of the festival's shows**. |

When a member hits the cap during online checkout, the order is refused with:

> This membership covers {N} {Festival Name} tickets in advance. Additional festival tickets are available at the box office on the day of each performance.

!!! tip "Box office sales bypass the cap"
    Orders created through the admin interface are exempt from the festival cap -- the limit governs *advance self-service* booking, and box office staff can always seat a member at the door or extend a courtesy. The membership's regular per-production quota still applies.

## How the Cap Is Counted

- All membership tickets on attending orders for any production in the festival count toward the cap.
- Cancelled and refunded orders do not count.
- The cap applies per membership, so each membership in a household is counted separately.
