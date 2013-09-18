#!/bin/bash -e

innobackupex --apply-log --defaults-file=/home/mysqlbackup/backup-my.cnf /home/mysqlbackup
