"""This test make sure docker-compose install in consul is consistent with
docker in the host machine.

We had an issue while building a Dockerfile which copy a symlink working
in the container but not on the host machine was failing.

Si if the service is properly working on this dedicated branch that should
be fine
"""
import requests

from . import base_case
from . import cluster


class WhenDeployingAServiceThatCopySymlinkWhileBuildingImage(
    base_case.ClusterTestCase
):

    def given_a_cluster_without_test_service(self):
        self.application = cluster.Application(
            'https://github.com/mlfmonde/cluster_lab_test_service',
            'docker_copy_symlink_working_on_ct_only'
        )
        self.cluster.cleanup_application(self.application)
        self.master = 'core1'

    def becauseWeDeployTheService(self):
        self.cluster.deploy_and_wait(
            master=self.master,
            slave=self.slave,
            application=self.application,
        )
        self.app = self.cluster.get_app_from_kv(self.application.app_key)

    def service_should_return_HTTP_code_200(self):
        '''we may add a dns server (bind9?) at some point to manage DNS'''
        session = requests.Session()
        response = session.get('http://service.cluster.lab')
        assert 200 == response.status_code
        session.close()
