#!/bin/bash -ex


tmp_dir=/tmp/mysql_backup

rm -rf $tmp_dir ||true
mkdir -p $tmp_dir

if [ -z "$SLAVE_HOST" ]; then
  echo "you MUST set the SLAVE_HOST"
  exit 1
fi

echo "cleaning up previous backup stage on slave"
ssh -i /home/mysqlbackup/.ssh/id_rsa -o StrictHostKeyChecking=no mysqlbackup@${SLAVE_HOST} "rm -rf backup_stage ||true"

echo "streaming backup to slave using mysqlbackup@${SLAVE_HOST}"
innobackupex --defaults-file=/etc/mysql/debian.cnf --compress --stream=xbstream $tmp_dir| ssh -i /home/mysqlbackup/.ssh/id_rsa -o StrictHostKeyChecking=no mysqlbackup@${SLAVE_HOST} "xbstream -x -C /home/mysqlbackup/backup_stage" 
