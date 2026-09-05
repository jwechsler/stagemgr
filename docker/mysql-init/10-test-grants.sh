#!/bin/bash
# Grant the application account its test databases.
#
# The mysql image's MYSQL_DATABASE/MYSQL_USER pair only grants the app user
# rights on the development database, so `rake db:create` and `rspec` inside the
# container fail with "Access denied for user ... to database 'stagemgr_test'".
# The image sources every *.sh in /docker-entrypoint-initdb.d with MYSQL_USER
# and MYSQL_ROOT_PASSWORD already in the environment, so widen the grant here.
#
# The wildcard covers per-checkout suffixes (stagemgr_test, stagemgr_test_b, ...)
# so parallel worktrees each get their own database. `_` is a single-character
# wildcard in MySQL grant patterns, hence the escaping in `stagemgr\_test%`.
#
# IMPORTANT: /docker-entrypoint-initdb.d runs ONLY when the data volume is empty.
# On a volume that already exists, run the same grant by hand once:
#
#   docker compose exec mysql \
#     mysql -uroot -p"$MYSQL_ROOT_PASSWORD" \
#       -e "GRANT ALL ON \`stagemgr\_test%\`.* TO '<DATABASE_USER>'@'%';"
#
set -e

mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
	GRANT ALL PRIVILEGES ON \`stagemgr\_test%\`.* TO '$MYSQL_USER'@'%';
	FLUSH PRIVILEGES;
EOSQL

echo "[mysql-init] granted '$MYSQL_USER' all privileges on stagemgr_test%"
