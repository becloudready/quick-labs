## doctl Command cheatsheet

```
doctl compute droplet create bcr-1 --size s-1vcpu-1gb    --image centos-7-x64 --region nyc1 --ssh-keys <key-id>
doctl compute droplet list --tag-name bcr --format Name,PublicIPv4

doctl compute droplet delete --tag-name becloudready

```

## doctl command to create 10 VMs quickly

```
for i in {1..10}; do doctl compute droplet create ansible-controller-$i --size s-1vcpu-1gb   --image centos-7-x64 --region nyc1 --ssh-keys <key> --tag-name becloudready; done
```
## doctl command to launch k8s clusters

```
./doctl kubernetes cluster create quick-labs-09 --region nyc2 --version 1.32.1-do.0 --maintenance-window saturday=02:00 --node-pool "name=quick-labs-09;size=s-2vcpu-4gb;count=3"
```
