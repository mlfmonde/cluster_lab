import consulate
import docker
import hashlib
import logging
import json
import time

from collections import namedtuple
from datetime import datetime
from os import path
from urllib import parse


logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


class Cluster:

    def __init__(self):
        self.consul = consulate.Consul()
        self.nodes = dict(
            core1=dict(
                docker_cli=docker.DockerClient(
                    base_url="unix:///tmp/docker_core1.sock"
                ),
            ),
            core2=dict(
                docker_cli=docker.DockerClient(
                    base_url="unix:///tmp/docker_core2.sock"
                ),
            ),
            core3=dict(
                docker_cli=docker.DockerClient(
                    base_url="unix:///tmp/docker_core3.sock"
                ),
            ),
            core4=dict(
                docker_cli=docker.DockerClient(
                    base_url="unix:///tmp/docker_core4.sock"
                ),
            ),
        )

    # communicate with consul
    def deploy_and_wait(
        self, master=None, slave=None, application=None, timeout=300,
        event_consumed=None
    ):
        """Deploy a service waiting the end end of deployment before carry on
        """
        def deploy_finished(kv_app_before, kv_app_after):
            if kv_app_before and kv_app_after:
                if kv_app_after.deploy_date > kv_app_before.deploy_date:
                    return True
                else:
                    return False
            else:
                if not kv_app_before:
                    if kv_app_after:
                        return True
                    else:
                        return False
                else:
                    return False

        if not event_consumed:
            event_consumed = deploy_finished

        self.fire_event_and_wait(
            application,
            'deploy',
            json.dumps(
                {
                    'repo': application.repo_url,
                    'branch': application.branch,
                    'master': master,
                    'slave': slave,
                }
            ),
            event_consumed,
            timeout
        )

    def destroy_and_wait(self, application, timeout=300, event_consumed=None):
        def deploy_finished(kv_app_before, kv_app_after):
            if not kv_app_after:
                return True
            else:
                return False

        if not event_consumed:
            event_consumed = deploy_finished

        self.fire_event_and_wait(
            application,
            'destroy',
            json.dumps(
                {
                    'repo': application.repo_url,
                    'branch': application.branch,
                }
            ),
            event_consumed,
            timeout
        )

    def fire_event_and_wait(
        self, application, event_name, payload, event_consumed, timeout
    ):
        app_before = self.get_app_from_kv(application.app_key)
        logger.info(
            "Emit %s event for ref/branch: %s with following payload: %r",
            event_name, application.branch, payload
        )
        event_id = self.consul.event.fire(
            event_name, payload
        )
        start_date = datetime.now()
        while not event_consumed(
                app_before, self.get_app_from_kv(application.app_key)
        ):
            time.sleep(1)
            if (datetime.now() - start_date).seconds > timeout:
                raise TimeoutError(
                    "Event (id: {}) was not processed in the expected time"
                    " ({}s),".format(event_id, timeout)
                )
        # Make sure caddy and happroxy are reload and service registered
        time.sleep(3)
        return event_id

    def get_app_from_kv(self, key):
        return json2obj(self.consul.kv.get(key))

    # Communicate with btrfs docker plugin
    def scheduled(self, volume_name, kind=None):
        """get btrfs scheduled definition for the given volume filtered by
        kind (purge, sync, replicate, ... ) if provide"""

    def cleanup_application(self, application):
        service = self.consul.catalog.service(
            application.name
        )
        if len(service) > 0:
            self.destroy_and_wait(application)
        # remove old snapshots
        for name, node in self.nodes.items():
            container = node['docker_cli'].containers.get(
                'buttervolume_plugin_1'
            )
            container.exec_run(
                'bash -c "'
                'btrfs subvolume delete /var/lib/docker/snapshots/{}*'
                '"'.format(
                    application.volume_prefix
                )
            )


def _json_object_hook(d):
    return namedtuple('X', d.keys())(*d.values())


def json2obj(data):
    if not data:
        return None
    return json.loads(data, object_hook=_json_object_hook)


class Application(object):
    """ class almost copied from cluster/consul/handler.py to generate
    service name
    """

    def __init__(self, repo_url, branch):
        self.repo_url, self.branch = repo_url.strip(), branch.strip()
        if self.repo_url.endswith('.git'):
            self.repo_url = self.repo_url[:-4]
        md5 = hashlib.md5(
            parse.urlparse(self.repo_url.lower()).path.encode('utf-8')
        ).hexdigest()
        repo_name = path.basename(self.repo_url.strip('/').lower())
        self.name = repo_name + (
            '_' + self.branch if self.branch else ''
        ) + '.' + md5[:5]  # don't need full md5

    @property
    def app_key(self):
        return 'app/{}'.format(self.name)

    @property
    def volume_prefix(self):
        return self.name.replace('.', '').replace('_', '') + '_'
