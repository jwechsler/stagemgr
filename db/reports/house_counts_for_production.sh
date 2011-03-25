mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/house_counts_for_production.sql;"

