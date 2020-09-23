import boto3
import botocore
import paramiko

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
instance[0].wait_until_running()           
instance[0].reload()
print(instance[0].public_dns_name)
print(instance[0].public_ip_address)

key = paramiko.RSAKey.from_private_key_file('C:/Users/Sonu_2/Downloads/Ansible.pem')
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

client.connect(hostname=instance[0].public_ip_address, username="ec2-user", pkey=key)

stdin, stdout, stderr = client.exec_command('sudo yum update -y')
stdout=stdout.readlines()
for line in stdout:
    output=output+line
if output!="":
    print (output)
else:
    print ("There was no output for this command")

client.close()
