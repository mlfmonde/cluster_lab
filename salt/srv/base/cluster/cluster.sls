{% set username = "core" %}
{% set cluster_repo = 'https://github.com/mlfmonde/cluster' %}
{% set cluster_rev = 'master' %}
{% set rootfs = '/rootfs' %}
{% set compose_binary = '/opt/bin/docker-compose' %}
{% set docker_volumes_dir = '/var/lib/docker/volumes' %}
{% set minion_btrfs_mount_point = '/mnt/local' %}

cluster-code:
    git.latest:
        - name: {{ cluster_repo }}
        - target: {{ rootfs }}/home/{{ username }}/cluster
        - rev: {{ cluster_rev }}
        - branch: testing
        - force_fetch: True
        - force_reset: True
        - force_checkout: True

# we could user docker to run containers from minion container
# but it's quite cheeper to define systemd unit to launch it than insalling
# docker clien in minion container
cluster-cluster-systemd-unit:
  file.managed:
    - name: {{ rootfs }}/etc/systemd/system/cluster.service
    - source: salt://cluster/docker-compose-unit.jinja
    - template: jinja
    - defaults:
        requires: docker.service
        working_directory: /home/{{ username }}/cluster
        compose_bin: {{ compose_binary }}
        compose_options: "-f docker-compose.yml -f docker-compose.override.yml"
#        type: "oneshot"
        cmd_startpre1: "pull"
        cmd_startpre2: "build"
        cmd_start: "up"
        cmd_stop: "stop"
#        remain_after_exit: "no"

cluster-deploy-directory:
  file.directory:
    - name: {{ rootfs }}/deploy
    - user: 100
    - makedirs: True

cluster-docker-compose-lab:
  file.managed:
    - name: {{ rootfs }}/home/{{ username }}/cluster/docker-compose.override.yml
    - source: salt://cluster/docker-compose.lab.yml.jinja
    - template: jinja
    - require:
      - git: cluster-code
      - file: cluster-deploy-directory

cluster_cluster_service_started:
  service.running:
    - name: cluster.service
    - enable: True
    - reload: True
    - require:
      - git: cluster-code
      - cmd: cluster_buttervolume_service_started
      - file: cluster-cluster-systemd-unit
      - file: cluster-docker-compose-lab
