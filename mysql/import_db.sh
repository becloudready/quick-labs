#!/bin/bash
DUMP_FILE=mysqlsampledatabase.sql
HOST=mydb1.ctiembqzvsd8.us-east-1.rds.amazonaws.com
USER=root

mysql -h$HOST -u $USE  -p  < $DUMP_FILE 
