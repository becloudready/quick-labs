#!/bin/bash
git clone https://github.com/datacharmer/test_db.git
cd test_db
DUMP_FILE=employees.sql
HOST=mydb1.ctiembqzvsd8.us-east-1.rds.amazonaws.com
USER=root

mysql -h$HOST -u$USER  -p  < $DUMP_FILE 

