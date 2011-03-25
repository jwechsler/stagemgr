#!/bin/bash

mysql -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/yesterdays_sales_revenue_by_performance.sql;" > /tmp/daily_sales_revenue_for_theater$1.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/yesterdays_sales_revenue_by_performance.sql;"



