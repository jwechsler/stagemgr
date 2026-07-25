# Staff Users

!!! info "Required Role"
    Only **Administrators** can create, edit, and manage user accounts.

**Navigation:** Options > Administer Users

## Overview

Every person who uses Stagemgr's admin interface needs a user account. User accounts control login access, determine what features are available (via roles), and scope data visibility (via theater assignments).

For a detailed breakdown of what each role can do, see [User Roles & Permissions](../getting-started/user-roles.md).

## The Users List

The Administer Users page shows all user accounts in a searchable, paginated table with columns for:

- **Email** -- The user's login email address
- **Role** -- Administrator, Box Office, or Producer (Theater User)
- **Status** -- Active or Inactive
- **Last Login** -- When the user last logged in
- **Actions** -- Edit and Destroy links

Use the search box to filter by email or name.

## Creating a User

1. Go to **Options > Administer Users**
2. Click **New User**
3. Fill in the form fields described below
4. Click **Create User**

## User Form Fields

### Email

The user's email address, which also serves as their login username. Must be unique and contain an `@` symbol. Maximum 100 characters.

### Status

| Status | Effect |
|--------|--------|
| **Active** | User can log in and access the system |
| **Inactive** | User cannot log in. Use this to disable accounts without deleting them. |

New accounts default to Active. Accounts also become Inactive on their own after
a long period of disuse -- see [Automatic Deactivation for
Inactivity](#automatic-deactivation-for-inactivity).

### Password / Password Confirmation

Set the user's password. Required when creating a new account. When editing an existing account, leave both fields blank to keep the current password unchanged.

Both fields must match.

### Associated Theaters

A multi-select list of all active theaters. Select one or more theaters to associate with this user.

!!! note "Theater Assignment and Roles"
    Theater assignment primarily matters for **Theater Users** (Producers). Theater Users can only see data -- productions, orders, reports -- for their assigned theaters. **Administrators** and **Box Office** staff see all active theaters regardless of what's selected here, but assigning theaters is still good practice for organizational clarity.

### Role Checkboxes

| Checkbox | Role Assigned | Access Level |
|----------|--------------|-------------|
| **Is Administrator** checked | Administrator | Full access to everything |
| **Is Box Office User** checked | Box Office | Day-to-day operations, all active theaters |
| Neither checked | Theater User (Producer) | Limited access, scoped to assigned theaters |

!!! warning
    If both checkboxes are checked, the user gets Administrator access (the highest privilege wins). To make someone Box Office, check only "Is Box Office User" and leave "Is Administrator" unchecked.

## Editing a User

Click **Edit** next to any user in the list. You can change their email, role, status, theater assignments, and password. Changes take effect on the user's next page load or login.

## Automatic Deactivation for Inactivity

Stagemgr expires unused logins. An account that goes **13 months** without any
login activity is set to **Inactive** automatically, whether or not it was ever
logged into -- an account created and never used expires 13 months after it was
created.

- A nightly maintenance job deactivates accounts that have passed the 13-month
  mark. No email is sent.
- The same rule is applied at the login screen, so an account past the mark
  cannot be used even in the window before the nightly job runs. The user sees a
  message telling them the account was deactivated for inactivity and to contact
  an administrator.
- Nothing is deleted. The account, its theater assignments, and its audit
  history are all preserved.

"Login activity" means the most recent of the account's last login and its last
page request -- the **Last Access Date** column on the Users list is the page
request half of that. Any normal use of the system, logging in or loading a
page, resets the clock, so an account used even once a year never expires.

### Reactivating an Expired Account

An Administrator reactivates the account the same way as any other Inactive
account: **Options > Administer Users**, click **Edit**, set **Status** back to
**Active**, and save. The password is unchanged, so the user can log in again
immediately -- and the reactivated account then has a fresh 13-month window.

!!! warning "Keep at least one Administrator account in use"
    The rule applies to Administrator accounts too. If every Administrator
    account went 13 months without a login, they would all be deactivated and
    no one could log in to reactivate them (recovering from that requires
    server-level database access). Logging in periodically avoids this.

## Deactivating vs Deleting Users

- **Deactivating** (setting Status to Inactive) is the recommended way to remove access. The user's account and all associated audit history is preserved.
- **Deleting** permanently removes the user account. Use this only for accounts created in error.

## Session Behavior

- Login sessions time out after **6 hours** of inactivity
- Accounts are deactivated after **13 months** without a login (see [Automatic
  Deactivation for Inactivity](#automatic-deactivation-for-inactivity))
- The dashboard shows login count, last login date/IP, and current login date/IP
- Users can change their own password via **My Account > Edit**
