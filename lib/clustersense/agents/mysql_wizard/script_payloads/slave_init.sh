#!/bin/bash -ex
if [ -z "$SYNC_USER" ]; then
  echo "SYNC_USER not set, using mysqlbackup@"
  SYNC_USER=mysqlbackup
fi

if [ -z "$MYSQL_MASTER" ]; then
  echo "MYSQL_MASTER must be set, aborting!"
  exit 1
fi

if [ -z "$BACKUP_STAGE" ]; then
  echo "BACKUP_STAGE not set, defaulting /home/$SYNC_USER/backup_stage"
  BACKUP_STAGE="/home/$SYNC_USER/backup_stage"
fi

replication_pass=$(cat /home/$SYNC_USER/backup_stage/replicationpw)
/etc/init.d/mysql stop
innobackupex --apply-log $BACKUP_STAGE 
cp $BACKUP_STAGE/debian.cnf /etc/mysql/debian.cnf
rsync -av --delete $BACKUP_STAGE/ /var/lib/mysql/
chown mysql:mysql /var/lib/mysql/
chown -R mysql:mysql /var/lib/mysql/*
/etc/init.d/mysql start
binlog_file=$(cat $BACKUP_STAGE/xtrabackup_binlog_info|cut -f1)
binlog_pos=$(cat $BACKUP_STAGE/xtrabackup_binlog_info|cut -f2)
mysql --defaults-file=/etc/mysql/debian.cnf -e "change master to master_host=\"${MYSQL_MASTER}\", master_user=\"repl\", master_password=\"${replication_pass}\", master_log_file=\"${binlog_file}\", master_log_pos=${binlog_pos};"
mysql --defaults-file=/etc/mysql/debian.cnf -e 'start slave;'
mysql --defaults-file=/etc/mysql/debian.cnf -e 'show slave status\G'
