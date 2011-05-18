#!/bin/bash

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/total_counts_by_production.sql;"



