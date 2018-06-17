# Integration testing

The goal of integration tests are to making sure each piece of the
infrastructure are working well for a given version.

## What's is tested

> **WARNING**: With the time I can forget to report here what's tested it's
> often better to read the code. I'll do my best to keep it updated.

### switch tests

There are a lot possible switch between 4 nodes, here the exaustived list
with differents case and where it's tested:

#### Master only

- deploy new master alone: None => core1, **we should add some tests but
  some tests by**:
    - [test_bind_relative_path.py](tests/test_bind_relative_path.py):
    - [test_docker_compose_version_consistency.py](
      tests/test_docker_compose_version_consistency.py):
- [ ] [move master to an other node]()
- [ ] [redeploy master on the same node]()

#### Two nodes master/slave

- [x] [new deploiement master/slave](tests/test_new_service.py):
  None/None => core1/core2
- [x] [switch slave <-> master](tests/test_reverse_service.py):
  core3/core4 => core4/core3
- [x] [redeploy same master/slave](tests/test_redeploy_service.py):
  core2/core3 => core2/core3
- [x] [redeploy new master/slave](tests/test_move_new_master_slave_whitout_caddy.py):
  core1/core4 => core3/core2
- [x] [redeploy keeping master](tests/test_change_slave_same_master.py):
  core4/core2 => core4/core1
- [x] [redeploy keeping slave](tests/test_change_master_same_slave.py):
  core4/core2 => core1/core2


#### Changing master/slave to master only

- [ ] [master/slave to master only]()
- [ ] [master only to master/slave]()

### There are some meet issues tested

- [x] [add new buttervolume volume](tests/test_change_master_same_slave.py)
  ***This test should be done in multiple cases today only one
  covered case: core4/core2 => core1/core2***
- [x] [remove volume](tests/test_change_slave_same_master.py)
- [x] [bind relative path in docker-compose](tests/test_bind_relative_path.py)
- [x] [deactivated haproxy config while switching](
  tests/test_disable_hapx_config_while_maintenance_mode.py)
- [x] [docker engine and docker-compose version consistency](
  tests/test_bind_relative_path.py)
- [x] [test bypassing the main caddyserver](
  tests/test_move_new_master_slave_whitout_caddy.py)

## TODO

A reminder about nice things to do

[ ] use images instead building Dockerfile
[ ] Add Docker image registry proxy cache server to avoid pulling from internet
    on each nodes:
    - https://docs.docker.com/registry/recipes/mirror/#use-case-the-china-registry-mirror
    - https://blog.docker.com/2015/10/registry-proxy-cache-docker-open-source/
[ ] Find a proper way to know anyblok db initialisation is over

## Setup test environment

* Make sure you have [spawn 4 nodes with `salt-cloud` and they were properly
  setup with `salt`](../README.md) that you can launch services on it

* create a python3 virtualenv and install dependencies

```bash
python3 -m venv path/to/venv
source path/to/venv/bin/activate
pip install -r requirements.txt
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

```bash250
ssh -L 8500:localhost:8500 core@192.168.122.95 -i salt/srv/base/ssh/core_id_rsa
```

* To each docker daemons, create an ssh tunnel to the socket for each nodes:

```bash
ssh -nNT -L /tmp/docker_core1.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.95
ssh -nNT -L /tmp/docker_core2.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.108
ssh -nNT -L /tmp/docker_core3.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.157
ssh -nNT -L /tmp/docker_core4.sock:/var/run/docker.sock -i ../salt/srv/base/ssh/core_id_rsa core@192.168.122.221
```

* To request the test service, you may update you ``/etc/hosts`` file to add
  the following entry (use any node IP address):

```bash
sudo echo "192.168.122.221  service.cluster.lab" >> /etc/hosts
sudo echo "192.168.122.221  service.qualif.cluster.lab" >> /etc/hosts
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


## Troubleshoot

Here some commons troubleshoots you can met;

### ConnectionError

While running contexts test case you can get a connection error:

```python
  raise ConnectionError(err, request=request)
requests.exceptions.ConnectionError: ('Connection aborted.', ConnectionRefusedError(111, 'Connection refused'))
```
This happens when the ``/tmp/docker_core?.sock`` file exists but the ssh
tunnel that bind the docker daemon socket stoped.

Make sure your coreos machine are up and ssh connection alive.

## RequestError

While running contexts test case you can get a Request error:

```python
  raise exceptions.RequestError(str(err))
consulate.exceptions.RequestError: HTTPConnectionPool(host='localhost', port=8500): Max retries exceeded with url: /v1/kv/app/cluster_lab_test_service_without_caddyfile.89b06 (Caused by NewConnectionError('<urllib3.connection.HTTPConnection object at 0x7f52153cfba8>: Failed to establish a new connection: [Errno 111] Connection refused',))
```

This happens when the ssh tunnel to connect to the consul API was stopped.

Make sure your consul cluster is alive and the api responding on
``localhost:8500`` (localhost where you are running testcase
)


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