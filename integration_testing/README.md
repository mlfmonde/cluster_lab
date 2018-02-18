# Integration testing


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

```bash
py.test  --hosts=core@192.168.122.45 test_infra.py 
# comme ci dessus il faut mettre en place le tunnel ssh sur la socket avant
# et exporter la variable d'environement DOCKER_HOST
py.test --connection=docker  --hosts=elegant_hodgkin test_infra.py  -v
```