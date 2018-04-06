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
DEFAULT_TIMEOUT = 600


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
        self,
        master=None,
        slave=None,
        application=None,
        timeout=DEFAULT_TIMEOUT,
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

    def destroy_and_wait(
        self, application, timeout=DEFAULT_TIMEOUT, event_consumed=None
    ):
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
        logger.info(
            "Event %s takes %ss to consume",
            event_name, (datetime.now() - start_date).seconds
        )
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

            def filter_schedule(schedule):
                if schedule.volume.startswith("clusterlabtestservice"):
                    return True

            scheduled_to_cleanup = self.get_scheduled(
                container, filter_schedule
            )

            for schedule in scheduled_to_cleanup:
                schedule.minutes = 0
                container.exec_run('buttervolume schedule {}'.format(
                    str(schedule))
                )
            container.exec_run(
                'bash -c "'
                'btrfs subvolume delete /var/lib/docker/snapshots/{}*'
                '"'.format(
                    application.volume_prefix
                )
            )
            container = node['docker_cli'].containers.get(
                'cluster_consul_1'
            )
            container.exec_run(
                'bash -c "rm -rf /deploy/{}*"'.format(
                    "cluster_lab_test_service"
                )
            )

    def get_scheduled(self, container, scheduled_filter, *args, **kwargs):
        """Get scheduled given a buttervolume container

        :param container: buttervolume container (docker api)
        :param scheduled_filter: a method to filter schedule, wich must
                                 return ``True`` to add the schedul to the
                                 list and ``False`` to ignore it::

            def allow_all_filter(schedule, *args, **kwargs):
                '''In this example no thing filtered, all schedul will be
                in the returned list'''
                return True

        :param args: args that are forward to the filtered method
        :param kwargs: kwargs forwared to the filterd method
        :return: a list of schedule
        """
        if not scheduled_filter:
            def default_filter(schedule, *args, **kwargs):
                return True
            scheduled_filter = default_filter
        return [
            s for s in [
                Scheduled.from_str(s) for s in container.exec_run(
                    'buttervolume scheduled'
                ).output.decode('utf-8').split('\n') if s
            ] if scheduled_filter(s, *args, **kwargs)
        ]


def _json_object_hook(d):
    return namedtuple('X', d.keys())(*d.values())


def json2obj(data):
    if not data:
        return None
    return json.loads(data, object_hook=_json_object_hook)


class Scheduled(object):
    """
    """

    _kind = None
    _kind_params = None
    _volume = None
    _minutes = None

    def __init__(self, kind, kind_params, volume, minutes):
        self._kind = kind
        self._kind_params = kind_params
        self._volume = volume
        self._minutes = minutes

    @property
    def kind(self):
        return self._kind

    @property
    def kind_params(self):
        return self._kind_params

    @property
    def minutes(self):
        return self._mintes

    @minutes.setter
    def minutes(self, value):
        self._mintes = value

    @property
    def volume(self):
        return self._volume

    @staticmethod
    def from_str(scheduled):
        schedule = scheduled.split(" ")
        if ':' in schedule[0]:
            kind_and_params = schedule[0].split(":")
            kind = kind_and_params[0]
            params = ":".join([str(s) for s in kind_and_params[1:]])
        else:
            kind, params = schedule[0], None
        return Scheduled(kind, params, schedule[2], schedule[1])

    def __str__(self):
        if self._kind_params:
            kind = ":".join([self._kind, self._kind_params])
        else:
            kind = self._kind
        return "{} {} {}".format(kind, self._minutes, self._volume)


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
