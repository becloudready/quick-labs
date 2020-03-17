import boto3

# for i in range(16):
i=1
rds = boto3.client('rds')
try:
    response = rds.create_db_instance(
    
    DBInstanceIdentifier='database-{}'.format(i),
    MasterUsername='admin',
    MasterUserPassword='admin123',
    DBInstanceClass='db.t2.micro',
    Engine='mysql',
    MultiAZ=False,
    PubliclyAccessible=True,
    DeletionProtection=False,
    AllocatedStorage=5)
    print (response)
except Exception as error:
    print (error)