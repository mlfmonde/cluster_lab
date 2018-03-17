# Integration testing

The goal of integration tests are to making sure each piece of the
infrastructure are working well for a given version.


## Setup test environment

* Make sure you have [spawn 4 nodes with `salt-cloud` and they were properly
  setup with `salt`](../README.md) that you can launch services on it

* create a python3 virtualenv and install dependencies

```bash

```

> *Note*: we may improve how test case access to consul, docker daemons, nodes
> and so on... But at the time I'm writing each solutions got cons so
> I avoid the question by setting up manually the environment before running
> tests

Before running those tests the test runner needs somme acces to diffenrent
pieces:

* list VM ips:

```bash
sudo salt '*' grains.get ip4_interfaces:eth0
```

* To consul, you need to open an ssh tunnel that consul is accessible on
  ``http://localhost:8500``:

```bash
ssh -L 8500:localhost:8500 core@192.168.122.32 -n -i salt/srv/base/ssh/core_id_rsa
```

* To each docker daemons, create an ssh tunnel to the socket for each nodes:

```bash
ssh -nNT -L /tmp/docker_core1.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.193
ssh -nNT -L /tmp/docker_core2.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.27
ssh -nNT -L /tmp/docker_core3.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.32
ssh -nNT -L /tmp/docker_core4.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.82
```

* To request the test service, you may update you ``/etc/hosts`` file to add
  the following entry (use any node IP address):

```bash
sudo echo "192.168.122.82  service.cluster.lab" >> /etc/hosts
```


## Running test case

> *information*: test case are written in a [Context-Specification style](
> http://contexts.readthedocs.io/en/v0.11.2/#about) using [Contexts](
> http://contexts.readthedocs.io) python testing framework


```bash
(testvenv) : /cluster_lab/integration_testing$ run-contexts tests/ -v -s
```

> *Note*: Firsts time you run tests they are quite slow as the base image (
> python:3-stretch) used in the test service is quite heavy and must be
> downloaded on each nodes. This depend on your network band width.

## POCs

### nuka

> **Note**: not tested, since I've moved to core user with dedicated ssh key
> you may condigure .ssh/config file to use the right private key
> ``salt/srv/base/ssh/core_id_rsa``

```bash
python -m venv venvs/nuka
source venvs/nuka/bin/activate

git clone git@github.com:bearstech/nuka

diff --git a/nuka/hosts/docker_host.py b/nuka/hosts/docker_host.py
index f7fa1dd..4adb09d 100644
--- a/nuka/hosts/docker_host.py
+++ b/nuka/hosts/docker_host.py
@@ -37,7 +37,7 @@ class DockerContainer(BaseHost):
                  **kwargs):
         kwargs.update(hostname=hostname, image=image)
         super().__init__(**kwargs)
-        self.cli = DockerClient()
+        self.cli = DockerClient(base_url="unix:///../path/to/this/repo/../cluster_lab/integration_testing/../docker.sock")
 
     @property
     def bootstrap_command(self):


pip install -e ./nuka --egg nuka[full]


cd cluster_lab/
https://medium.com/@dperny/forwarding-the-docker-socket-over-ssh-e6567cfab160
ssh -nNT -L $(pwd)/docker.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.45

cd integration_testing/
export DOCKER_HOST=unix://$(pwd)/../docker.sock
python test_nuka.py  -v --debug
```

### test infra

> **Note**: you needs to bind docker.socket as in nuka's POC

```bash
py.test  --hosts=core@192.168.122.45 test_infra.py 
# comme ci dessus il faut mettre en place le tunnel ssh sur la socket avant
# et exporter la variable d'environement DOCKER_HOST
py.test --connection=docker  --hosts=elegant_hodgkin test_infra.py  -v
```