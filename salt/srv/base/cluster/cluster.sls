{% set username = "core" %}
{% set cluster_repo = 'https://github.com/petrus-v/cluster' %}
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
#        remain_after_exit: "no"

cluster-cluster-systemd-unit:
  file.managed:
    - name: {{ rootfs }}/etc/systemd/system/cluster.service
    - source: salt://cluster/docker-compose-unit.jinja
    - template: jinja
    - defaults:
        working_directory: /home/{{ username }}/cluster
        compose_bin: {{ compose_binary }}
        compose_options: "-f docker-compose.yml -f docker-compose.lab.yml"
#        type: "oneshot"
        cmd_start: "up --build"
        cmd_stop: "stop"
#        remain_after_exit: "no"

cluster-deploy-directory:
  file.directory:
    - name: {{ rootfs }}/home/{{ username }}/deploy
    - user: 100
    - makedirs: True

cluster-docker-compose-lab:
  file.managed:
    - name: {{ rootfs }}/home/{{ username }}/cluster/docker-compose.lab.yml
    - source: salt://cluster/docker-compose.lab.yml.jinja
    - template: jinja
    - defaults:
        deploy_path: /home/{{ username }}/deploy
    - require:
      - git: cluster-code
      - file: cluster-deploy-directory

cluster_reload_systemd:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: cluster-buttervolume-systemd-unit
      - file: cluster-cluster-systemd-unit

cluster_buttervolume_service_started:
  cmd.run:
    - name: systemctl start buttervolume.service
    - unless:
      - systemctl status buttervolume.service
    - require:
      - file: cluster-buttervolume-systemd-unit
      - git: cluster-code
      - cmd: btrfs_subvolume_mount_volumes
      - cmd: cluster_reload_systemd
      - file: docker-compose-executable

cluster_cluster_service_started:
  cmd.run:
    - name: systemctl start cluster.service
    - unless:
      - systemctl status cluster.service
    - require:
      - git: cluster-code
      - cmd: cluster_buttervolume_service_started
      - cmd: cluster_reload_systemd
      - file: cluster-cluster-systemd-unit
      - file: cluster-docker-compose-lab

cluster_buttervolume_ssh_private_key:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/volumes/buttervolume_buttervolume_ssh/_data/id_rsa
    - source: salt://ssh/buttervolume_id_rsa
    - mode: 400
    - require:
      - cmd: cluster_buttervolume_service_started

cluster_buttervolume_ssh_pub_key:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/volumes/buttervolume_buttervolume_ssh/_data/id_rsa.pub
    - source: salt://ssh/buttervolume_id_rsa.pub
    - require:
      - cmd: cluster_buttervolume_service_started

cluster_buttervolume_ssh_authorized_keys:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/volumes/buttervolume_buttervolume_ssh/_data/authorized_keys
    - source: salt://ssh/buttervolume_id_rsa.pub
    - require:
      - cmd: cluster_buttervolume_service_started

cluster_buttervolume_ssh_config:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/volumes/buttervolume_buttervolume_ssh/_data/config
    - contents: |
        Host *
          StrictHostKeyChecking no
    - require:
      - cmd: cluster_buttervolume_service_started
