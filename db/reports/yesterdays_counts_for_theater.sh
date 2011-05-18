#!/bin/bash

mysql -u stagemgr_prod stagemgr -e "set @theater_id:=$1; source ~/stagemgr/db/reports/sql/yesterdays_sales_counts_by_performance.sql;" > /tmp/daily_sales_count_for_theater$1.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @theater_id:=$1; source ~/stagemgr/db/reports/sql/yesterdays_sales_counts_by_performance.sql;"



