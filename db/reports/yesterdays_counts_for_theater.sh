#!/bin/bash

export PATH="$PATH:/usr/local/mysql/bin:/usr/local/bin"
SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"

mysql -u stagemgr_prod stagemgr -e "set @theater_id:=$1; source $SCRIPTPATH/sql/yesterdays_sales_counts_by_performance.sql;" > /tmp/daily_sales_count_for_theater$1.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @theater_id:=$1; source $SCRIPTPATH/sql/yesterdays_sales_counts_by_performance.sql;"
