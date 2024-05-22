# kubernetes-the-hard-way
Supporting and modified scripts for [kubernetes-the-hard-way](https://github.com/kubernetes-the-hard-way/kubernetes-the-hard-way)

The repo has been updated from using GCP to be cloud provider agnostic.

Notes here include some GCP setup, partly taken from the [previous commit](https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/79a3f79b27bd28f82f071bb877a266c2e62ee506) using GCP and customisations.

Apart from using GCP for the infrastructure, the repo has been updated to use terraform to provision the infrastructure.

See the [terraform](terraform) folder for the scripts.


Sections below describe the modifications and notes from the original docs.

# 1. Prerequisites - Provisioning using GCP

Each of jumpbox, server, node-0 and node-1 are provisioned using GCP. Use terraform scripts addded to the repo to achieve this. Make sure gcloud is setup with the project, region and zone to use.

Reference the repo [kubernetes-the-hard-way](https://github.com/kubernetes-the-hard-way/kubernetes-the-hard-way) at the commit before the change to be cloud provider agnostic. There are instructions for GCP here. 

In particular, network, subnetwork, firewall and load ballancer IP should be set according to the old docs.

## 3. Compute Resources

### SSH

SSH setup is slightly different given GCP. That said, still go with the simple root login. Could just as easily use the gcloud ssh as described in the old version of the docs, but to keep it simple, change to the updated docs and create a key for root SSH login on all boxes. Block SSH traffic on the external IP to all but the jumpbox. Internal IP ranges can be open.

### Hostnames

GCP debian installs just have `127.0.0.1` as localhost, not the additional `127.0.1.1` with the hostname.

So the initial sed command to edit /etc/hosts doesn't work. Keep using the original command in case this changes or if using another OS or cloud provider.

Add another command to echo the line for `127.0.1.1 FQDN HOSTNAME` to /etc/hosts.

```bash
while read IP FQDN HOST SUBNET; do 
    CMD="echo -e '127.0.1.1\t${FQDN} ${HOST}' >> /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl hostname ${HOST}
done < machines.txt
```

TODO: Verify the below command is working

Don't do the above which could result in two entries but first check for whether there is a 127.0.1.1 entry in /etc/hosts and if so, use the original command to edit /etc/hosts.

```bash
while read IP FQDN HOST SUBNET; do 
    CMD="grep -q '127.0.1.1' /etc/hosts && sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts || echo -e '127.0.1.1\t${FQDN} ${HOST}' >> /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl hostname ${HOST}
done < machines.txt
```

or alternative form using "here document"

```bash
while read IP FQDN HOST SUBNET; do 
    ssh -n root@${IP} <<EOF
if grep -q '127.0.1.1' /etc/hosts; then
    sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts
else
    echo -e '127.0.1.1\t${FQDN} ${HOST}' >> /etc/hosts
fi
hostnamectl hostname ${HOST}
EOF
done < machines.txt
```

## 4. Provisioning the CA and Generating TLS Certificates

TODO: looks like there's an error in the ca.conf for `kube-controller-manager` `subjectAltName. All other `DNS:xxx` has been set with the name of the section/object but here it looks like it's copy-paste error with `DNS:kube-proxy` incorrectly set instead of `DNS:kube-controller-manager`. Need to verify if this needs to be fixed.

Original section:

```
# Controller Manager
[kube-controller-manager]
distinguished_name = kube-controller-manager_distinguished_name
prompt             = no
req_extensions     = kube-controller-manager_req_extensions

[kube-controller-manager_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "Kube Controller Manager Certificate"
subjectAltName       = DNS:kube-proxy, IP:127.0.0.1
subjectKeyIdentifier = hash
```

Corrected section:

```
# Controller Manager
[kube-controller-manager]
distinguished_name = kube-controller-manager_distinguished_name
prompt             = no
req_extensions     = kube-controller-manager_req_extensions

[kube-controller-manager_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "Kube Controller Manager Certificate"
subjectAltName       = DNS:kube-controller-manager, IP:127.0.0.1
subjectKeyIdentifier = hash
```

## 5. Kubernetes Configuration Files

When generating the configs, it's necessary to specify the server address. In the original docs this is given as
```
https://server.kubernetes.local:6443
```

By default, GCP sets different local FQDN that include the zone/region and project, so we have to set this appropriately.

There are two ways to deal with this.

1. Keep the use of `<hostname>.kubernetes.local` throughout. This is simplest. To do so, make sure to set the `/etc/hosts` file appropriately. This domain won't work in the GCP infrastructure or their commands without manually adding and modifying DNS for the VPC. This is an option but not even needed here becuase all the work is done within the VPC from jumpbox and server.
2. Change all references to use the subnet domain and DNS automatically appied to GCP VPC subnets. This of the form `<hostname>.<zone>.<region>.<project>.internal` e.g. `server.us-central1-f.c.k8s-from-scratch-0-422016.internal`.

Option `1` is simple enough to need no more instructions.

### Option 2

Use the command, replacing the `--server=...` appropriately with the FQDN for the `server` instance. Get this using `ssh -n server hostname --fqdn` or on the box directly. This has to be done for all following commands that do the same, or just set an env variable to use in all subsequent commands.


```bash
for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.<INTERNAL_NETWORK_NAME>:6443 \ # !!! REPLACE ME
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done
```


## 6. Data Encryption Keys

The config file that should be in the subdirectory `configs/encryption-config.yaml` is missing due to a previous commit that added it to `.gitignore`. This was presumably to prevent the file that's generated by substituting in the encryption key from being committed. Sadly, both the original is removed from the repo and nothing can be committed without fixing this.

There is an [issue: configs/encryption-config.yaml is missing](https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/768) and PR [Fix encryption-config.yaml is missing issue #780](https://github.com/kelseyhightower/kubernetes-the-hard-way/pull/780) that fixes this.

The quick fix, without pulling in the pull request is just to add the file back to where it should be manually, then run the command as instructed.

`configs/encryption-config.yaml`
```yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
```

Create manually or using:

```bash
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```



## 7 Bootstrapping etcd

Suspect there's an error in the `--name` option for starting the etcd daemon in the systemd services file `etcd.service`.

The current file has the name parameter as `--name controller`. But the instructions just before this say to set the name to the host name of the current compute instance.

Similarly in the [docs for etcd clustering](https://etcd.io/docs/v3.5/op-guide/clustering/) suggest using the hostname. As do the old docs for the previous version of kubernetes-the-hard-way -- but in this case there were multiple controllers so it was necesesary to discriminate. 

Keep as `controller` and see if it works. Should be easy to fix if not.

**IP:** Another point of note is that in the docs they use the external IP (on the local subnet, not fully external), rather than the loopback as is used in the docs here. Again, stick with as is and see if it works anyway.



## 9. Bootstrapping Kubernetes Workers

There's an error in the scp command. It overwrites the `kubelet-config.yaml` that was just edited and copied over in the previous loop over nodes doing sed then scp of exactly this file.

It's just the one line in otherwise ok. 

Use the following command:

```bash
for host in node-0 node-1; do
  scp \
    downloads/runc.arm64 \
    downloads/crictl-v1.28.0-linux-arm.tar.gz \
    downloads/cni-plugins-linux-arm64-v1.3.0.tgz \
    downloads/containerd-1.7.8-linux-arm64.tar.gz \
    downloads/kubectl \
    downloads/kubelet \
    downloads/kube-proxy \
    configs/99-loopback.conf \
    configs/containerd-config.toml \
    configs/kube-proxy-config.yaml \
    units/containerd.service \
    units/kubelet.service \
    units/kube-proxy.service \
    root@$host:~/
done
```

## 11. Pod Network Routes

The updated instructions for setup on bare-metal/ infrastructure independent instances seems to cause issues with the network routes needed when the setup has been done using GCP.

The setup in this repo used the old instructions for instances and VPC, subnet, firewalls, and hence network routes. When trying to set the route to the CIDR for the kubernetes subnets there's an error that there isn't a valid next hop. 

Specifically, we need to be able to reach 10.200.[0,1].0/24 (the kubernetes pod CIDRs for nodes 0, 1) via each of the nodes' subnet IPs 10.240.0.2[0,1]. This should be the next hop for any route that needs 10.200.[0,1].0/24.

This command fails

```bash
{
  SERVER_IP=$(grep server machines.txt | cut -d " " -f 1)
  NODE_0_IP=$(grep node-0 machines.txt | cut -d " " -f 1)
  NODE_0_SUBNET=$(grep node-0 machines.txt | cut -d " " -f 4)
  NODE_1_IP=$(grep node-1 machines.txt | cut -d " " -f 1)
  NODE_1_SUBNET=$(grep node-1 machines.txt | cut -d " " -f 4)
}

ssh root@server <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

ssh root@node-0 <<EOF
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}

EOF
```

Instead we need to use the [old instructions](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/79a3f79b27bd28f82f071bb877a266c2e62ee506/docs/11-pod-network-routes.md) and set the routes using GCP gcloud commands. 

TODO: This could also be converted and added to terraform.

Print the internal IP address and Pod CIDR range for each worker instance (note the change from `worker-[0,1,2]` to `node-[0,1]`):

```bash
for instance in node-0 node-1; do
  gcloud compute instances describe ${instance} \
    --format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[1].value)'
done
```

The `metadata.item` index is dependent on any other metadata set and the order, so check what's needed for the `pod-cidr`.

> output

```
10.240.0.20 10.200.0.0/24
10.240.0.21 10.200.1.0/24
```

Note that the VPC in this setup is called `terraform-network` not `kubernetes-the-hard-way` as it is in the original instructions. The subnet is the same name `kubernetes`.

```bash
for i in 0 1; do
  gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
    --network terraform-network \
    --next-hop-address 10.240.0.2${i} \
    --destination-range 10.200.${i}.0/24
done
```


```bash 
gcloud compute routes list --filter "network: terraform-network"
```

> output

```
NAME                            NETWORK            DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-2ecc0779a97ec3c4  terraform-network  10.240.0.0/24  terraform-network         0
default-route-cfb9ea6bb1a4cf0a  terraform-network  0.0.0.0/0      default-internet-gateway  1000
kubernetes-route-10-200-0-0-24  terraform-network  10.200.0.0/24  10.240.0.20               1000
kubernetes-route-10-200-1-0-24  terraform-network  10.200.1.0/24  10.240.0.21               1000
```