#!/bin/bash

PATH=$PATH:/usr/local/mysql/bin

mysql -u stagemgr_prod stagemgr -e 'set @all_shows:=1; source ~/stagemgr/db/reports/sql/previous_week_revenue_by_performance.sql;' > /tmp/previous_week_box_office_revenue.txt

mysql --table=true -u stagemgr_prod stagemgr -e 'set @all_shows:=1; source ~/stagemgr/db/reports/sql/previous_week_revenue_by_performance.sql;'

mysql --table=true -u stagemgr_prod stagemgr -e 'set @all_shows:=1; source ~/stagemgr/db/reports/sql/previous_week_revenue_total.sql;'



