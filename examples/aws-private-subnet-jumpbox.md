![AWS Jumpbox](https://github.com/user-attachments/assets/5bf904e4-911b-4536-9f15-746cf9d47f8f)

```
+----------------+       +----------------+       +----------------+
| Local Machine  |       |  Jump Server   |       | Internal Machine |
|                |       | (Bastion Host) |       |                |
|  +----------+  |       |  +----------+  |       |  +----------+  |
|  | Terminal |  |  SSH  |  | SSH      |  |  SSH  |  | Service  |  |
|  |          |--------->|  | Server   |--------->|  |          |  |
|  +----------+  |       |  +----------+  |       |  +----------+  |
|                |       |                |       |                |
+----------------+       +----------------+       +----------------+
```

Connection Flow:
1. Local Machine: ssh -J user@jumpserver user@internalmachine
   OR
2. Local Machine: ssh user@jumpserver
   Jump Server: ssh user@internalmachine

### Steps

1. Setup the VPC with Public and Private Subnets

![image](https://github.com/user-attachments/assets/26366a75-55da-4288-a80b-91f6359eead6)


2. Launch the Public subnet EC Instance ( create key )

Setup the downloaded key in your local machine

```
chmod 400 ~/us-east-1-quick-lab-instance.pem
ssh add ~/us-east-1-quick-lab-instance.pem
```
3. Test if you are able to connect

```
+----------------+       +----------------+
| Local Machine  |       |  Jump Server   |
|                |       | (Bastion Host) |
|  +----------+  |       |  +----------+  |
|  | Terminal |  |  SSH  |  | SSH      |  |
|  |          |--------->|  | Server   |  |
|  +----------+  |       |  +----------+  |
|                |       |                |
+----------------+       +----------------+

Connection:
Local Machine: ssh ubuntu@ec2-44-195-128-107.compute-1.amazonaws.com
```

4. Launch the Private subnet ec2 and ensure Public Subnet ec2 is able to ssh to private subnet ec2
5. Setup ssh key on Public subnet ec2 ( the jump server )
Put the Private key here
```
 ~/.ssh/id_ecdsa
```

8. Test the connection 
```
+----------------+       +----------------+
|  Jump Server   |       | Private Server |
| (Bastion Host) |       |                |
|  +----------+  |       |  +----------+  |
|  | SSH      |  |  SSH  |  | Service  |  |
|  | Client   |--------->|  |          |  |
|  +----------+  |       |  +----------+  |
|                |       |                |
+----------------+       +----------------+

Connection:
Jump Server: ssh ubuntu@ip-10-0-136-37.ec2.internal
```
5. Now Validate end to end connection

```
+----------------+       +----------------+       +----------------+
| Local Machine  |       |  Jump Server   |       | Internal Machine |
|                |       | (Bastion Host) |       |                |
|  +----------+  |       |  +----------+  |       |  +----------+  |
|  | Terminal |  |  SSH  |  | SSH      |  |  SSH  |  | Service  |  |
|  |          |--------->|  | Server   |--------->|  |          |  |
|  +----------+  |       |  +----------+  |       |  +----------+  |
|                |       |                |       |                |
+----------------+       +----------------+       +----------------+

ssh ubuntu@ip-10-0-136-37.ec2.internal -J ubuntu@ec2-44-195-128-107.compute-1.amazonaws.co

```
