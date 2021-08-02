## doctl commands

```
for i in {1..8}; do doctl compute droplet create ansible-controller-$i --size s-1vcpu-1gb   --image centos-7-x64 --region nyc1 --ssh-keys 13:b5:9e:1c:67:ad:bb:89:ed:13:7b:cb:83:61:ed:a9 --tag-name becloudready; done
```
