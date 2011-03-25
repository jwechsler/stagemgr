#!/bin/bash

export EMAIL="boxoffice@theaterwit.org"

export PATH=$PATH:/usr/local/mysql/bin

test -r /sw/bin/init.sh && . /sw/bin/init.sh

SCRIPT=`readlink -f $0`
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`

d=`date -v -1d +"%a, %b %d"`

echo "

Ticket Counts:

" >> /tmp/previous_week_box_office.txt

$SCRIPTPATH/previous_week_box_office_counts.sh >> /tmp/previous_week_box_office.txt

echo "
Revenue:
" >> /tmp/previous_week_box_office.txt

$SCRIPTPATH/previous_week_box_office_revenue.sh >> /tmp/previous_week_box_office.txt


echo "Attachments included (in tab-delimited format):
previous_week_box_office_counts.txt -- Sales count by performance and ticket type for all performances
previous_week_box_office_revenue.txt -- Revenue by performance for all shows
" >> /tmp/previous_week_box_office.txt

mutt -s "[TheaterWit] Box Office Weekly Counts/Revenue - all theaters" -a /tmp/previous_week_box_office_counts.txt -a /tmp/previous_week_box_office_revenue.txt  $1 < /tmp/previous_week_box_office.txt

rm /tmp/previous_week_box_office.txt /tmp/previous_week_box_office_counts.txt /tmp/previous_week_box_office_revenue.txt



