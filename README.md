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

