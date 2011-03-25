mysql -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/previous_week_counts_by_performance.sql;" > /tmp/previous_week_box_office_counts.txt

mysql --table=true -u stagemgr_prod stagemgr -e "set @prod_code:='$1'; source ~/stagemgr/db/reports/sql/previous_week_counts_by_performance.sql;"

