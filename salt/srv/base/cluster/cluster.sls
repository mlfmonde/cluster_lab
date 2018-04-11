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
        - force_reset: True
        - force_checkout: True

# we could user docker to run containers from minion container
# but it's quite cheeper to define systemd unit to launch it than insalling
# docker clien in minion container
cluster-buttervolume-systemd-unit:
  file.managed:
    - name: /rootfs/etc/systemd/system/buttervolume.service
    - source: salt://cluster/docker-compose-unit.jinja
    - template: jinja
    - defaults:
        compose_bin: {{ compose_binary }}
        working_directory: /home/{{ username }}/cluster/buttervolume
        compose_options: "-f docker-compose.yml"
#        type: "simple"
        cmd_start: "up --build"
        cmd_stop: "stop"
        requires: docker.service
#        remain_after_exit: "no"

cluster-cluster-systemd-unit:
  file.managed:
    - name: {{ rootfs }}/etc/systemd/system/cluster.service
    - source: salt://cluster/docker-compose-unit.jinja
    - template: jinja
    - defaults:
        requires: docker.service buttervolume.service
        working_directory: /home/{{ username }}/cluster
        compose_bin: {{ compose_binary }}
        compose_options: "-f docker-compose.yml -f docker-compose.override.yml"
#        type: "oneshot"
        cmd_start: "up --build"
        cmd_stop: "stop"
#        remain_after_exit: "no"

cluster-deploy-directory:
  file.directory:
    - name: {{ rootfs }}/deploy
    - user: 100
    - makedirs: True

docker-plugin-directory:
  file.directory:
    - name: {{ rootfs }}/var/run/docker/plugins
    - dir_mode: 755

cluster-docker-compose-lab:
  file.managed:
    - name: {{ rootfs }}/home/{{ username }}/cluster/docker-compose.override.yml
    - source: salt://cluster/docker-compose.lab.yml.jinja
    - template: jinja
    - require:
      - git: cluster-code
      - file: cluster-deploy-directory

cluster_buttervolume_service_started:
  service.running:
    - name: buttervolume.service
    - enable: True
    - reload: True
#    - onchanges:
#      - file: cluster-buttervolume-systemd-unit
    - require:
      - file: cluster-buttervolume-systemd-unit
      - git: cluster-code
      - service: btrfs_subvolume_mount_volumes
      - file: docker-compose-executable

cluster_cluster_service_started:
  service.running:
    - name: cluster.service
    - enable: True
    - reload: True
#    - onchanges:
#      - file: cluster-cluster-systemd-unit
    - require:
      - git: cluster-code
      - service: btrfs_subvolume_mount_volumes
      - service: cluster_buttervolume_service_started
      - file: cluster-cluster-systemd-unit
      - file: cluster-docker-compose-lab

cluster_buttervolume_ssh_private_key:
  file.managed:
    - name: {{ rootfs }}{{ docker_volumes_dir }}/buttervolume_buttervolume_ssh/_data/id_rsa
    - source: salt://ssh/buttervolume_id_rsa
    - mode: 400
    - require:
      - service: btrfs_subvolume_mount_volumes

cluster_buttervolume_ssh_pub_key:
  file.managed:
    - name: {{ rootfs }}{{ docker_volumes_dir }}/buttervolume_buttervolume_ssh/_data/id_rsa.pub
    - source: salt://ssh/buttervolume_id_rsa.pub
    - require:
      - service: btrfs_subvolume_mount_volumes

cluster_buttervolume_ssh_authorized_keys:
  file.managed:
    - name: {{ rootfs }}{{ docker_volumes_dir }}/buttervolume_buttervolume_ssh/_data/authorized_keys
    - source: salt://ssh/buttervolume_id_rsa.pub
    - require:
      - service: btrfs_subvolume_mount_volumes

cluster_buttervolume_ssh_config:
  file.managed:
    - name: {{ rootfs }}{{ docker_volumes_dir }}/buttervolume_buttervolume_ssh/_data/config
    - contents: |
        Host *
          StrictHostKeyChecking no
    - require:
      - service: btrfs_subvolume_mount_volumes
