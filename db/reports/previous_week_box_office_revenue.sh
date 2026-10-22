#!/bin/bash

export PATH="$PATH:/usr/local/mysql/bin:/usr/local/bin"
SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"

mysql -u stagemgr_prod stagemgr -e "set @all_shows:=1; source $SCRIPTPATH/sql/previous_week_revenue_by_performance.sql;" > /tmp/previous_week_box_office_revenue.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @all_shows:=1; source $SCRIPTPATH/sql/previous_week_revenue_by_performance.sql;"

mysql --table=true -u stagemgr_prod stagemgr -e "set @all_shows:=1; source $SCRIPTPATH/sql/previous_week_revenue_total.sql;"
