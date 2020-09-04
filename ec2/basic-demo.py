import logging
import pprint
import time
import urllib.request
import boto3


logger = logging.getLogger(__name__)

def create_instance():
    ec2 = boto3.resource('ec2')
    instance = ec2.create_instances(
        ImageId = 'ami-0be47bda7578c98d5',
        MinCount = 1,
        MaxCount = 1,
        InstanceType = 't2.micro',
        KeyName = 'ansible'
    )

def run_demos():
    """
    """
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    print('-'*88)
    print("Welcome to the AWS Python Demo.")
    print('-'*88)

    current_ip_address = urllib.request.urlopen('http://checkip.amazonaws.com')\
        .read().decode('utf-8').strip()
    
   
if __name__ == '__main__':
    run_demos()
