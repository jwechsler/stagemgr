# Flex Pass Offers

!!! info "Who uses this?"
    **Box Office Managers** configure flex pass offers to sell multi-ticket packages that patrons can redeem across multiple productions over time.

**Navigation:** Admin > Offers > Flex Pass Offers

---

## Overview

A flex pass is a prepaid ticket package. The patron purchases a set number of tickets at a fixed price and then redeems them for individual performances over a defined period. Flex passes encourage repeat attendance and provide upfront revenue.

## Creating a Flex Pass Offer

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

## Managing Flex Pass Offers

- **Deactivate** an offer by unchecking the **Active** checkbox. Existing purchased passes remain valid until they expire.
- **Remove from public sale** by unchecking **On Sale to Public** while keeping the offer active for box office sales.
- Changes to an offer (price, number of tickets) apply only to future purchases and do not affect already-sold passes.
