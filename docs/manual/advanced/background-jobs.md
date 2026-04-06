# Background Jobs

!!! info "Required Role"
    **Administrator** can view the Job Queue in the Options menu. **Box Office** users can initiate operations that run as background jobs but cannot directly manage the queue.

**Navigation:** Options > Job Queue (Administrators only)

## Overview

Many Stagemgr operations take too long to complete during a single page load -- generating a large report, importing hundreds of records, or recalculating house counts across dozens of performances. Instead of making you wait, Stagemgr runs these operations as **background jobs**.

When you start an operation that runs in the background, you will typically see a confirmation message, and the results will be delivered to you (usually by email) when the job completes.

## What Runs in the Background?

The following operations are processed as background jobs:

### Report Generation

| Report | Delivery Method |
|--------|-----------------|
| Production Attendees Report | Emailed as CSV attachment |
| Flex Pass Patron Report (Download) | Emailed as CSV attachment |
| Donation List Export | Emailed as CSV attachment |
| Membership Usage Export | Emailed as CSV attachment |
| Weekly Box Office Report | Emailed as CSV attachment |
| Order Dump | Emailed as CSV attachment |
| Customer Data Mining | Emailed as CSV attachment |

When you click **Download** on a report, the job is queued and you will receive the completed CSV by email. You do not need to keep the browser open.

!!! tip "Show vs. Download"
    Some reports offer both a **Show** option (displays results in the browser immediately) and a **Download** option (generates a CSV in the background). Use Show for quick lookups and Download for large datasets.

### Imports

All [import operations](../imports/imports-overview.md) run as background jobs:

- TRG Arts Order File Import
- Mailing List Signup Cards Import
- External Contact Data Import
- Bulk Orders Import
- Flex Pass Orders Import
- Donor Levels Import

After uploading your CSV, the import is queued for processing. Results and any error reports are emailed to you when the import completes.

### House Count Calculations

House counts -- the real-time inventory snapshot showing sold, held, and available seats for each performance -- are recalculated periodically by a background job. This ensures that the house count data on your dashboard and in reports stays current without requiring manual intervention.

### Email Delivery

Patron emails are sent through background jobs, including:

- Order confirmation emails
- Follow-up emails after performances
- Performance broadcast emails (sent to all attendees of a specific performance)
- Import error reports
- Report delivery emails

Emails are queued and sent within minutes. Failed emails are automatically retried up to **8 times** before being marked as permanently failed.

## Job Queue

Administrators can monitor background job activity through the **Job Queue** page:

**Navigation:** Options > Job Queue

The Job Queue shows:

| Information | Description |
|-------------|-------------|
| **Pending jobs** | Jobs waiting to be processed |
| **Active workers** | Jobs currently running |
| **Failed jobs** | Jobs that encountered errors |
| **Queue sizes** | Number of jobs in each priority queue |

### Job Priorities

Stagemgr uses multiple priority queues to ensure time-sensitive operations complete first:

| Priority | Typical Operations |
|----------|-------------------|
| **High** | Email delivery, order confirmations |
| **Default** | House count calculations, standard operations |
| **Low** | Large report generation, data exports, imports |

Higher-priority jobs are processed before lower-priority ones, so patron-facing emails are not delayed by a large report export running in the background.

## What to Expect

### Timing

| Operation | Typical Duration |
|-----------|-----------------|
| Single email send | Seconds |
| Small import (under 100 rows) | Under 1 minute |
| Large import (1,000+ rows) | Several minutes |
| Standard report | 1--5 minutes |
| Large report (full season data) | 5--15 minutes |
| House count recalculation | Runs continuously in the background |

### Notifications

You will receive an email when:

- A report you requested is ready (with the CSV attached)
- An import completes (with success count and any error report)
- A background operation fails and requires attention (Administrators only)

!!! note "No Browser Notification"
    Stagemgr does not send browser push notifications for completed jobs. Check your email for results. You can also return to the imports page or report page to see updated status.

## Troubleshooting

### "My report hasn't arrived"

1. **Check your spam/junk folder** -- automated emails sometimes land there
2. **Wait a few more minutes** -- large reports can take up to 15 minutes
3. **Check the Job Queue** (Administrators) -- look for failed jobs that may need attention
4. **Try again** -- if the job failed, you can re-request the report

### "My import seems stuck"

1. **Check your email** -- the import may have completed with errors, and the error report is in your inbox
2. **Return to the imports page** -- status updates appear there when an import finishes
3. **Contact an administrator** -- if you do not have Job Queue access, an admin can check the queue status

### "Emails are not being sent"

If patron emails seem delayed or missing:

1. Emails queue in the **high-priority** queue and are typically sent within seconds to minutes
2. Failed emails automatically retry up to 8 times
3. An administrator can check the Job Queue for stuck or failed email jobs
4. Verify the patron's email address is valid and not a placeholder
