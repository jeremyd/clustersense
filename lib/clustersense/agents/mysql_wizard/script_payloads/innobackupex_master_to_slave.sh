#!/bin/bash -ex                                                                                                                                                              

if [ -z "$TMP_DIR" ]; then
  echo "TMP_DIR not set, using /tmp/mysql_backup"                                                                                                                            
  TMP_DIR=/tmp/mysql_backup
fi

rm -rf $TMP_DIR ||true
mkdir -p $TMP_DIR

if [ -z "$SLAVE_HOST" ]; then
echo "you MUST set the SLAVE_HOST"                                                                                                                                           
  exit 1
fi

if [ -z "$SYNC_USER" ]; then
  echo "SYNC_USER not set, using mysqlbackup@"                                                                                                                               
  SYNC_USER=mysqlbackup
fi

if [ -z "$MYSQL_PASSWORD" ]; then
  echo "MYSQL_PASSWORD not set, defaulting to empty password."                                                                                                               
  MYSQL_PASSWORD_CMD=""
else
  MYSQL_PASSWORD_CMD="--password ${MYSQL_PASSWORD}"
fi

if [ -z "$MYSQL_USER" ]; then
  echo "MYSQL_USER not set, defaulting to root."
  MYSQL_USER_CMD="--user root"
else
  MYSQL_USER_CMD="--user ${MYSQL_USER}"
fi

if [ -z "$DEST_DIR" ]; then
  echo "DEST_DIR not set, defaulting /home/$SYNC_USER/backup_stage"
  DEST_DIR="/home/$SYNC_USER/backup_stage"
fi

echo "cleaning up previous backup stage on slave"                                                                                                                            
ssh -i /home/${SYNC_USER}/.ssh/id_rsa -o StrictHostKeyChecking=no ${SYNC_USER}@${SLAVE_HOST} "rm -rf /home/$SYNC_USER/backup_stage ||true"
ssh -i /home/${SYNC_USER}/.ssh/id_rsa -o StrictHostKeyChecking=no ${SYNC_USER}@${SLAVE_HOST} "mkdir -p /home/$SYNC_USER/backup_stage ||true"

cat /etc/mysql/grants.sql |grep "GRANT REPLICATION" |cut -f10 -d" "| sed s%\;%% |sed "s%'%%g" > /etc/mysql/replicationpw
scp -i /home/${SYNC_USER}/.ssh/id_rsa -o StrictHostKeyChecking=no /etc/mysql/replicationpw ${SYNC_USER}@${SLAVE_HOST}:/home/$SYNC_USER/backup_stage/replicationpw
rm /etc/mysql/replicationpw
scp -i /home/${SYNC_USER}/.ssh/id_rsa -o StrictHostKeyChecking=no /etc/mysql/debian.cnf ${SYNC_USER}@${SLAVE_HOST}:/home/$SYNC_USER/backup_stage/debian.cnf
innobackupex $MYSQL_USER_CMD $MYSQL_PASSWORD_CMD --defaults-file=/etc/mysql/my.cnf --stream=tar $TMP_DIR| ssh -i /home/$SYNC_USER/.ssh/id_rsa -o StrictHostKeyChecking=no $SYNC_USER@${SLAVE_HOST} "tar -xif - -C ${DEST_DIR}"
