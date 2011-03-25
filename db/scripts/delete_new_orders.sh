echo "delete from orders where status = 'New' and convert_tz(updated_at,'UTC','SYSTEM') < addtime(now(), '-0:30:00');" | /usr/local/mysql/bin/mysql -u stagemgr_prod stagemgr

 
