#!/bin/bash

# Envelope sender for mutt/mailx, and the recipient for the reports that do
# not take one as an argument. Set REPORT_EMAIL in the cron environment to
# your box office address. No default: a report quietly mailed to a
# placeholder address is worse than a cron job that fails loudly.
: "${REPORT_EMAIL:?set REPORT_EMAIL in the cron environment (e.g. boxoffice@yourtheater.org)}"
export EMAIL="$REPORT_EMAIL"

export PATH="$PATH:/usr/local/mysql/bin:/usr/local/bin"

SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"

cat $SCRIPTPATH/sql/unfulfilled_flexpass.sql | mysql --vertical -u stagemgr_prod stagemgr | mailx -E -s "[${REPORT_SUBJECT_TAG:-StageMgr}] Unfulfilled Flexpasses" "$EMAIL"
