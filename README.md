# Cluster lab

The intent of the project is to offer a lab to develop new fictionalises
or fix bug in cluster project without breaking production.

An other intent would be to provide an automated integration platform.

> **DISCLAMER**: Do not use to deploy cluster in production notably because
> ssh keys are public in salt/srv/base/ssh for testing purpose

Finaly that can be an example of ways to spawn virtual machine for
test environment.

## Workstation or host requirements

> **Note**: This documentation was tested on Debian 9 (stretch)

* add [salt repo](https://repo.saltstack.com/#debian) and update your indexes
* install dependencies:
  ```bash
  sudo apt install salt-cloud libvirt-daemon salt-master libvirt-clients virt-manager
  ```
* get [stable coreos image](
  https://coreos.com/os/docs/latest/booting-with-libvirt.html):
  ```bash
  $ wget https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc
  gpg --import CoreOS_Image_Signing_Key.asc
  # vérifier l'ID de l clefs https://coreos.com/security/image-signing-key/
  # actuellement: 0412 7D0B FABE C887 1FFB  2CCE 50E0 8855 93D2 DCB4 (valide jusqu'en 2018-06-01)
  $ gpg --edit-key buildbot@coreos.com
  gpg (GnuPG) 2.1.18; Copyright (C) 2017 Free Software Foundation, Inc.
  This is free software: you are free to change and redistribute it.
  There is NO WARRANTY, to the extent permitted by law.
  
  
  pub  rsa4096/50E0885593D2DCB4
       created: 2013-09-06  expires: never       usage: SC  
       trust: unknown       validity: unknown
  sub  rsa4096/A541ECB274E7E361
       created: 2013-09-06  expired: 2014-09-06  usage: S   
  sub  rsa4096/A5A96635E5676EFC
       created: 2014-09-08  expired: 2015-09-08  usage: S   
  sub  rsa4096/07FA9ED31CB5FA26
       created: 2015-08-31  expired: 2017-08-30  usage: S   
  The following key was revoked on 2016-05-16 by RSA key 50E0885593D2DCB4 CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>
  sub  rsa4096/8633FB13B58844F1
       created: 2015-11-20  revoked: 2016-05-16  usage: S   
  sub  rsa4096/48F9B96A2E16137F
       created: 2016-05-16  expired: 2017-05-16  usage: S   
  sub  rsa4096/DE2F8F87EF4B4ED9
       created: 2017-05-22  expires: 2018-06-01  usage: S   
  [ unknown] (1). CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>
  
  gpg> fpr
  pub   rsa4096/50E0885593D2DCB4 2013-09-06 CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>
   Primary key fingerprint: 0412 7D0B FABE C887 1FFB  2CCE 50E0 8855 93D2 DCB4
  # After checking the fingerprint, you may sign the key to validate it.
  # Since key verification is a weak point in public-key cryptography, 
  # you should be extremely careful and always check a key's fingerprint with 
  # the owner before signing the key.
  gpg> sign
  # Once signed you can check the key to list the signatures on it and see the
  # signature that you have added. Every user ID on the key will have one or
  # more self-signatures as well as a signature for each user that has validated the key.
  gpg> check
  wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_qemu_image.img.bz2{,.sig}
  gpg --verify coreos_production_qemu_image.img.bz2.sig
  bunzip2 coreos_production_qemu_image.img.bz2
  ```
> **Note**: if you want an old core-os version url may looks like
> ```bash
> wget https://stable.release.core-os.net/amd64-usr/1465.7.0/coreos_production_qemu_image.img.bz2{,.sig}
> ```


## Prepare template coreos image (test using qemu)

```bash
root@yourmachine:~# cd /var/lib/libvirt/images
root@yourmachine:/var/lib/libvirt/images# mkdir coreos
root@yourmachine:/var/lib/libvirt/images# cd coreos/
root@yourmachine:/var/lib/libvirt/images/coreos# cp path_to_coreos_production_qemu_image.img .
root@yourmachine:/var/lib/libvirt/images/coreos# qemu-img create -f qcow2 -b coreos_production_qemu_image.img coreos-template.qcow2
Formatting 'coreos-template.qcow2', fmt=qcow2 size=9116319744 backing_file=coreos_production_qemu_image.img encryption=off cluster_size=65536 lazy_refcounts=off refcount_bits=16
root@yourmachine:/var/lib/libvirt/images/coreos# ls -l
total 823112
-rw-r--r-- 1 root root 842661888 janv.  4 18:18 coreos_production_qemu_image.img
-rw-r--r-- 1 root root    196744 janv.  4 18:28 coreos-template.qcow2
```

> *Note*: This will create a coreos-template.qcow2 snapshot image.
> Any changes to container-linux1.qcow2 will not be reflected in
> coreos_production_qemu_image.img. Making any changes to a base image (
> coreos_production_qemu_image.img in our example) will corrupt its snapshots.

## Prepare cloud-init virtual Compact Disk (.iso)

```bash
mkdir -p provision/openstack/latest
vim provision/openstack/latest/user_data
[genisoimage|mkisofs] -R -V config-2 -o coreos-provision.iso provision/
```

> **Tips**: You can mount iso image as disk partition likes this
> ```bash
> mkdir mountprov
> mount -o loop coreos-provision.iso mountprov/
> ```


## Prepare BTRFS disk image for RAID0 (.qcow2)

```bash
qemu-img create -f qcow2 /var/lib/libvirt/images/coreos/btrfs1.img 25G
qemu-img create -f qcow2 /var/lib/libvirt/images/coreos/btrfs2.img 25G
```


## Prepare virt domain and create the template machine

> *Good to know*: a domain in virtlib glossary means a virtual machine

```bash
virt-install --connect qemu:///system \
             --import \
             --name coreos-template \
             --ram 1024 --vcpus 1 \
             --os-type=linux \
             --os-variant=virtio26 \
             --disk path=/var/lib/libvirt/images/coreos/coreos-template.qcow2,format=qcow2,bus=virtio \
             --disk path=/var/lib/libvirt/images/coreos/btrfs1.img,format=qcow2,bus=virtio \
             --disk path=/var/lib/libvirt/images/coreos/btrfs2.img,format=qcow2,bus=virtio \
             --disk path=/var/lib/libvirt/images/coreos/coreos-provision.iso,device=cdrom \
             --network network=default \
             --network network=private_network \
             --vnc --noautoconsole \
             --print-xml > /var/lib/libvirt/images/coreos/domain.xml
```


```bash
virsh net-create private_network.xml 
virsh define domain.xml
```

Congrat's you get it !


### virsh command nice to know

* Get VM IP address on default network

```bash
virsh net-dhcp-leases default
ssh -i salt/srv/base/ssh/core_id_rsa core@192.168.122.x
```

* start a VM from command line (do not miss virt-manager GUI)
```bash
virsh start coreos-template
```

* save a network configuration

```bash
virsh net-dumpxml private_network > private_network.xml
```

## prepare coreos-template before clone it

Some of this may probably later manage by salt itself or the image provided in
an other way.

In order to be able to spawn multiple nodes of the same coreos we needs to
prepare specifics requirements inside coreos machine likes cloning cluster,
upgrade coreos and so on, format BTRFS partitions...


## configure salt-cloud

In order to let salt cloud and salt-cloud to use configuration from this repo
you may adapt default salt configuration.

* clone this repo somewhere (if not already done!)
* link salt config to this repo

    sudo ln -s "${PWD}/salt/etc/" /etc/salt
    sudo ln -s "${PWD}/salt/srv/" /srv/salt


## use salt-cloud to spawn nodes

The following command will clone 3 coreos-template called *c1*, *c2*, *c3* and
run salt minion container inside each node:

```bash
salt-cloud -p coreos c1 c2 c3
```
or using a map file:

```bash
sudo salt-cloud -m cluster-saltcloud.map -P
```

> *Note*: ``-P`` allow to run in parallels

List available nodes:

```bash
sudo salt-cloud -f list_nodes libvirt
```

Refresh grains modules (stored in ``salt://_grains``):

```bash
sudo salt 'core*' saltutil.sync_grains
```

Refresh mine before apply states:

```bash
sudo salt '*' mine.update
```

apply states
```bash
sudo salt '*' state.apply
```


Then you can run salt commands likes:

```bash
# list minion keys
salt-key -L

# test ping
salt 'c*' test.ping

# get info from mingion

salt 'cor*' grains.items

# remove minion key
salt-key -d core1
```

Destroy nodes:

```bash
salt-cloud -d c1 c2 c3
```

Or using a map file:

```bash
sudo salt-cloud -m cluster-saltcloud.map -d
```

### network management

### simulate SAN behaviours


## sent consul envents

## launch integration scripts

