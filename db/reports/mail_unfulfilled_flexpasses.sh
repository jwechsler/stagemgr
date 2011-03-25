#!/bin/bash

export EMAIL="boxoffice@theaterwit.org"

export PATH=$PATH:/usr/local/mysql/bin

test -r /sw/bin/init.sh && . /sw/bin/init.sh

SCRIPT=`readlink -f $0`
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`

cat $SCRIPTPATH/sql/unfulfilled_flexpass.sql | mysql --vertical -u stagemgr_prod stagemgr | mailx -E -s "Unfulfilled Flexpasses" $EMAIL


