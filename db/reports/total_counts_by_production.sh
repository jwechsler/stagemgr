#!/bin/bash

export PATH="$PATH:/usr/local/mysql/bin:/usr/local/bin"
SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)"

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source $SCRIPTPATH/sql/total_counts_by_production.sql;"
