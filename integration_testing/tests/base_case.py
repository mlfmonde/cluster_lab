"""Base case, provide cluster specific assertion and cluster
facilities to make test easy to read.
"""
from . import cluster
from docker import errors


class ClusterTestCase:

    def __init__(self):
        self.cluster = cluster.Cluster()

    def assert_key_exists(self, key):
        """Make sure a key exists in the consul k/v store"""
        assert key in self.cluster.consul.kv

    def assert_volume_exists_only_on(self, volume, node_name, kind='local'):
        for name, node in self.cluster.nodes.items():
            volumes = node['docker_cli'].volumes.list(
                filters=dict(name=volume)
            )
            if node_name == name:
                assert len(volumes) == 1, \
                    "We expect 1 volume named {} on node {}, " \
                    "found {} volumes {}".format(
                        volume, node_name, len(volumes),
                        [v.name for v in volumes]
                    )
                assert volumes[0].attrs['Driver'] == kind,\
                    "Volume {} on node {} use {} driver, {} was " \
                    "expected".format(
                        volume, node_name, volumes[0].attrs['Driver'], kind
                    )
            else:
                assert len(volumes) == 0, \
                    "We expect 0 volume called {} on node {}, " \
                    "found {} volumes {}".format(
                        volume, node_name, len(volumes),
                        [v.name for v in volumes]
                    )

    def assert_consul_service_on_node(self, service_id, node):
        assert self.cluster.consul.catalog.service(
            service_id
        )[0]['Node'] == node

    def assert_btrfs_scheduled(self, kind, volume, nodes):
        """Assert btrfs scheduled are present on given nodes and absent on
        others"""

        def filter_scheduled(scheduled, start, end):
            return [
                s for s in scheduled if (
                    s.startswith(start) and s.endswith(end)
                )
            ]

        for name, node in self.cluster.nodes.items():
            container = node['docker_cli'].containers.get(
                'buttervolume_plugin_1'
            )
            scheduled = filter_scheduled(
                container.exec_run(
                    'buttervolume scheduled'
                ).output.decode('utf-8').split('\n'),
                kind,
                volume
            )
            if name in nodes:
                assert len(scheduled) == 1
            else:
                assert len(scheduled) == 0

    def assert_container_running_on(self, containers, nodes):
        for name, node in self.cluster.nodes.items():
            for container_name in containers:
                try:
                    container = node['docker_cli'].containers.get(
                        container_name
                    )
                except errors.NotFound:
                    container = None
                    pass

            if name in nodes:
                assert container.status == 'running'
            else:
                assert container is None
