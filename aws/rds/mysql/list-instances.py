#!/usr/bin/env python
import boto3
rds = boto3.client('rds')
try:
    # get all of the db instances
    dbs = rds.describe_db_instances()
    for db in dbs['DBInstances']:
        print ("{}".format(db['Endpoint']['Address']))
except Exception as error:
    print (error)