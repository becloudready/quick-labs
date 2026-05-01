#!/usr/bin/env python
import sys
import boto3
# db = sys.argv[1]
rds = boto3.client('rds')

for i in range(1,2):
    db = 'database-{}'.format(i)
    try:
        response = rds.delete_db_instance(
        DBInstanceIdentifier=db,
        SkipFinalSnapshot=True)
        print (response)
    except Exception as error:
        print (error)