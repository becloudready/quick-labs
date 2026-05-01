import boto3
import botocore
import paramiko
import time

ec2 = boto3.resource('ec2', region_name='us-east-1')
instance = ec2.create_instances(
    ImageId = 'ami-0c94855ba95c71c99',
    MinCount = 1,
    MaxCount = 1,
    InstanceType = 't2.micro',
    KeyName = 'Ansible',
    SecurityGroupIds=[
        'sg-0a946195e26dcdd80',
    ],
)
print (instance[0].id)
