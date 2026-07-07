# Flex Pass Offers

!!! info "Who uses this?"
    **Box Office Managers** configure flex pass offers to sell multi-ticket packages that patrons can redeem across multiple productions over time.

**Navigation:** Admin > Offers > Flex Pass Offers

---

## Overview

A flex pass is a prepaid ticket package. The patron purchases a set number of tickets at a fixed price and then redeems them for individual performances over a defined period. Flex passes encourage repeat attendance and provide upfront revenue.

## Creating a Flex Pass Offer

![Flex pass offer form with name, price, number of tickets, ticket class code, and use restrictions](../assets/images/screenshots/offers-flex-pass-form.png)

### Required Fields

| Field | Description |
|-------|-------------|
| **Name** | Display name shown to customers (e.g., "6-Show Season Pass"). |
| **Price** | Total purchase price for the flex pass. |
| **Number of Tickets** | How many individual tickets are included in the pass. |
| **Months Till Expiration** | Number of months from purchase date until the pass expires. |

### Ticket Redemption Settings

| Field | Description |
|-------|-------------|
| **Use Ticket Class Code** | The ticket class assigned when a flex pass ticket is redeemed. Selected from the list of Default Ticket Classes. |
| **Maximum Uses Per Production** | Limits how many pass tickets can be redeemed for a single production. Leave blank for no limit. |
| **Code Prefix** | Optional prefix added to generated flex pass codes for easy identification (e.g., `FP2026-`). |

!!! tip "Controlling redemption spread"
    Set **Maximum Uses Per Production** to encourage patrons to attend a variety of shows rather than using all tickets on a single production.

### Visibility and Status

| Field | Description |
|-------|-------------|
| **Active** | Whether the offer can be purchased and redeemed. |
| **On Sale to Public** | Whether the offer appears on the public-facing website. When unchecked, the pass can only be sold through the box office. |

### Theater Restrictions

| Field | Description |
|-------|-------------|
| **Theater** | Optionally restrict redemption to a specific theater. |
| **Exclude Theater** | When checked with a theater selected, the pass is valid everywhere *except* that theater. |

### Financial Fields

| Field | Description |
|-------|-------------|
| **Flat Payout** | Fixed dollar amount paid to the producing company per redeemed ticket. |
| **Spiff** | Additional per-ticket incentive amount. |
| **Facility Fee** | Per-ticket facility fee applied on redemption. |

!!! warning "Financial fields affect settlement"
    Flat Payout, Spiff, and Facility Fee values are used in financial settlement calculations between the venue and producing companies. Coordinate with your finance team before changing these.

### Special Modes

| Field | Description |
|-------|-------------|
| **Treat as Festival Pass** | When enabled, the pass behaves as a festival pass -- all tickets are redeemed at once for a set of performances rather than individually over time. |
| **Redeem Immediately** | When enabled, the system prompts the patron to select performances and redeem tickets immediately at the time of purchase. |

### Descriptions

| Field | Description |
|-------|-------------|
| **Short Description** | Brief summary displayed in offer listings and checkout. |
| **Long Description** | Full description displayed on the flex pass detail page. |

### Tags

Tags are free-form labels you can attach to a flex pass offer to group it for analysis and reporting -- for example by season, package family, partner, or any attribute you want to slice by later. Tags are arbitrary text you define and can change at any time.

A flex pass offer can have any number of tags. They appear as rounded pill labels in the **Tags** field on the offer form, next to the offer name in the Flex Pass Offers list, and on the offer detail page.

#### Adding a tag

1. Click into the **Tags** field on the flex pass offer form.
2. Begin typing. As you type, a dropdown suggests existing tag names already used on other flex pass offers -- click one to apply it, or keep typing to create a brand-new tag.
3. Press **Enter** (or type a comma) to commit the tag as a pill.
4. Repeat to add as many tags as you need, then save the form.

Click the **x** on any pill to remove that tag. Tags are matched case-insensitively, and removing a tag from one offer leaves it available on any others that use it.

!!! tip "Search by tag"
    The search box on the Flex Pass Offers list matches tag names as well as offer names, so you can quickly filter the list down to every offer sharing a tag.

---

## How Redemption Works

1. A patron purchases a flex pass and receives a pass code.
2. When attending a show, the patron provides their pass code at the box office or enters it online.
3. The system verifies the pass is active, not expired, and has remaining tickets.
4. A ticket is issued using the **Use Ticket Class Code** defined on the offer.
5. The remaining ticket count on the pass decreases by one.

If **Maximum Uses Per Production** is set, the system enforces that limit across all redemptions for that production.

!!! tip "Festival pass redemption"
    When **Treat as Festival Pass** is enabled, the patron selects all performances at once. This is ideal for multi-show festivals where attendees pick their full schedule upfront.

---

## Expiration

Flex passes expire based on the **Months Till Expiration** value, counted from the date of purchase. Once expired:

- The pass can no longer be used to redeem tickets.
- Any unredeemed tickets are forfeited.

!!! warning "Expired passes cannot be extended"
    Once a flex pass has expired, it cannot be reactivated through the offer settings. Contact a system administrator if an exception is needed.

---

## The Flex Pass Offers List

![Flex pass offers list showing tag pills, red Inactive labels, and blue theater-restriction labels in the Restrictions column](../assets/images/screenshots/offers-flex-pass-list.png)

Each row on the Flex Pass Offers list has an actions column with **Edit**, **Destroy**, and **Create Order** buttons. The **Create Order** button is shown greyed out and disabled for offers that are not active, since inactive offers cannot be sold.

The **Restrictions** column summarizes an offer's status and scope using small labels:

| Label | Meaning |
|-------|---------|
| Red **Inactive** | The offer's **Active** checkbox is unchecked -- it cannot be purchased or redeemed. |
| Blue **Only [Theater]** | Redemption is restricted to the named theater (the **Theater** field with **Exclude Theater** unchecked). |
| Blue **All but [Theater]** | Redemption is allowed everywhere except the named theater (the **Theater** field with **Exclude Theater** checked). |

An offer can show both an Inactive label and a theater-restriction label at the same time.

---

## Managing Flex Pass Offers

- **Deactivate** an offer by unchecking the **Active** checkbox. Existing purchased passes remain valid until they expire.
- **Remove from public sale** by unchecking **On Sale to Public** while keeping the offer active for box office sales.
- Changes to an offer (price, number of tickets) apply only to future purchases and do not affect already-sold passes.
