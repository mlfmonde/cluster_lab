"""Introspection of Docker minion host server.

In case salt-minion is running on docker container here some utilies to
introspect hostmachine
"""
import ConfigParser as configparser
import io
import os

HOST_ROOT = '/rootfs'


def host_info():
    """Return a dict parsing /rootfs/etc/os-release file
    """
    grains = {'docker_host': True, }
    os_release_file = os.path.join(
        HOST_ROOT, 'etc', 'os-release'
    )
    if os.path.isfile(os_release_file):
        with open(os_release_file, 'r') as f:
            config_string = '[release]\n' + f.read()
        config = configparser.ConfigParser()
        # config.read_string(config_string)
        config.readfp(io.BytesIO(config_string))
        grains = {
            'docker_host': {
                key: value for key, value in config.items('release')
            }
        }
    return grains
