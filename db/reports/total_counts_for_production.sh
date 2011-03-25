#!/bin/bash

mysql -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/total_counts_by_performance.sql;" > /tmp/total_sales_count_for_theater$1.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/total_counts_by_performance.sql;"



