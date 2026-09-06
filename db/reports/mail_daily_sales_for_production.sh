#!/bin/bash

# Envelope sender for mutt/mailx, and the recipient for the reports that do
# not take one as an argument. Set REPORT_EMAIL in the cron environment to
# your box office address. No default: a report quietly mailed to a
# placeholder address is worse than a cron job that fails loudly.
: "${REPORT_EMAIL:?set REPORT_EMAIL in the cron environment (e.g. boxoffice@yourtheater.org)}"
export EMAIL="$REPORT_EMAIL"

export PATH=$PATH:/usr/local/mysql/bin

test -r /sw/bin/init.sh && . /sw/bin/init.sh

export dotlock_program=/sw/bin/mutt_dotlock

SCRIPT=`readlink -f $0`
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`

d=`date -v -1d +"%a, %b %d"`

echo "
Ticket Sales on $d

Sales count (last 24 hours):
" > /tmp/daily_sales$1.txt

$SCRIPTPATH/yesterdays_counts_for_production.sh $1 >> /tmp/daily_sales$1.txt

echo "
Revenue (last 24 hours):
" >> /tmp/daily_sales$1.txt

$SCRIPTPATH/yesterdays_revenue_for_production.sh $1 >> /tmp/daily_sales$1.txt

echo "
Ticket Sales as of $d:

Sales Count (total, pre-reconciliation)
" >> /tmp/daily_sales$1.txt

$SCRIPTPATH/total_counts_for_production.sh $1 >> /tmp/daily_sales$1.txt

echo "
Revenue (as of $d):
" >> /tmp/daily_sales$1.txt

$SCRIPTPATH/total_revenue_for_production.sh $1 >> /tmp/daily_sales$1.txt

# echo "
# Special Offer Redemptions (if any):
# " >> /tmp/daily_sales$1.txt

# $SCRIPTPATH/total_special_offers_by_sale_date.sh $1 >> /tmp/daily_sales$1.txt

echo "Attachments included (in tab-delimited format):
daily_sales_count_for_theater$1.txt -- Ticket counts sold $d
daily_sales_revenue_for_theater$1.txt -- Ticket revenue sold $d
total_sales_count_for_theater$1.txt -- Sales count by performance and ticket type for all performances
total_sales_revenue_for_theater$1.txt -- Revenue by performance for all shows
total_special_offers_by_sale_date$1.txt -- Special offer order counts by sale date
" >> /tmp/daily_sales$1.txt

touch /tmp/daily_sales_count_for_theater$1.txt /tmp/daily_sales_revenue_for_theater$1.txt /tmp/total_sales_count_for_theater$1.txt /tmp/total_sales_revenue_for_theater$1.txt /tmp/total_special_offers_by_sale_date$1.txt

mutt -s "[${REPORT_SUBJECT_TAG:-StageMgr}] Ticket report ($d)" -a /tmp/daily_sales_count_for_theater$1.txt -a /tmp/daily_sales_revenue_for_theater$1.txt -a /tmp/total_sales_count_for_theater$1.txt -a /tmp/total_sales_revenue_for_theater$1.txt -a /tmp/total_special_offers_by_sale_date$1.txt "$2" < /tmp/daily_sales$1.txt

rm /tmp/daily_sales_count_for_theater$1.txt /tmp/daily_sales_revenue_for_theater$1.txt /tmp/total_sales_count_for_theater$1.txt /tmp/total_sales_revenue_for_theater$1.txt /tmp/total_special_offers_by_sale_date$1.txt


