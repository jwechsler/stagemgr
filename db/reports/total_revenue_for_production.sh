#!/bin/bash

export PATH="$PATH:/usr/local/mysql/bin:/usr/local/bin"
SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"

mysql -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source $SCRIPTPATH/sql/total_revenue_by_performance.sql;" > /tmp/total_sales_revenue_for_theater$1.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source $SCRIPTPATH/sql/total_revenue_by_performance.sql;"

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source $SCRIPTPATH/sql/total_revenue_by_production.sql;"
