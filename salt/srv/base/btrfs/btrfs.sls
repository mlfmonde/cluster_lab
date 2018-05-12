{% set rootfs = '/rootfs' %}
{% set dev1 = '/dev/vdb' %}
{% set dev2 = '/dev/vdc' %}
{% set buttervolume_dir = '/var/lib/buttervolume' %}
{% set minion_btrfs_mount_point = '/mnt/local' %}

btrfs_format:
  cmd.run:
    - name: mkfs.btrfs -f {{ dev1 }} {{ dev2 }}
    - unless: btrfs device ready {{ dev1 }}

btrfs_mount_local:
  mount.mounted:
    - name: {{ minion_btrfs_mount_point }}
    - device: {{ dev1 }}
    - fstype: btrfs
    - mkmnt: True
    - require:
      - cmd: btrfs_format

btrfs_subvolume_create_snapshots:
  cmd.run:
    - name: btrfs subvolume create {{ minion_btrfs_mount_point }}/snapshots
    - unless: btrfs subvolume show {{ minion_btrfs_mount_point }}/snapshots
    - require:
      - mount: btrfs_mount_local

btrfs_subvolume_create_volumes:
  cmd.run:
    - name: btrfs subvolume create {{ minion_btrfs_mount_point }}/volumes
    - unless: btrfs subvolume show {{ minion_btrfs_mount_point }}/volumes
    - require:
      - mount: btrfs_mount_local

buttervolume_config:
  file.directory:
    - name: {{ minion_btrfs_mount_point }}/config
    - require:
      - mount: btrfs_mount_local

buttervolume_ssh:
  file.directory:
    - name: {{ minion_btrfs_mount_point }}/ssh
    - require:
      - mount: btrfs_mount_local

btrfs_systemd_mount_unit:
  file.managed:
    - name: {{ rootfs }}/etc/systemd/system/var-lib-buttervolume.mount
    - source: salt://btrfs/btrfs-subvolume.mount.jinja
    - template: jinja
    - defaults:
        device: {{ dev1 }}
        mount_point: {{ buttervolume_dir }}

btrfs_subvolume_mount:
  service.running:
    - name: var-lib-buttervolume.mount
    - enable: True
    - reload: True
    - onchanges:
      - file: btrfs_systemd_mount_unit
    - require:
      - cmd: btrfs_subvolume_create_snapshots
      - cmd: btrfs_subvolume_create_volumes
      - file: buttervolume_config
      - file: buttervolume_ssh

buttervolume_ssh_private_key:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/ssh/id_rsa
    - source: salt://ssh/buttervolume_id_rsa
    - mode: 400
    - require:
      - service: btrfs_subvolume_mount

buttervolume_ssh_pub_key:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/ssh/id_rsa.pub
    - source: salt://ssh/buttervolume_id_rsa.pub
    - require:
      - service: btrfs_subvolume_mount

buttervolume_ssh_authorized_keys:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/ssh/authorized_keys
    - source: salt://ssh/buttervolume_id_rsa.pub
    - require:
      - service: btrfs_subvolume_mount

buttervolume_ssh_config:
  file.managed:
    - name: {{ minion_btrfs_mount_point }}/ssh/config
    - contents: |
        Host *
          StrictHostKeyChecking no
    - require:
      - service: btrfs_subvolume_mount

cluster_buttervolume_service_started:
  cmd.run:
    - name: docker plugin install --grant-all-permissions anybox/buttervolume:latest
    - unless: docker plugin  ls | grep true
    - require:
      - service: btrfs_subvolume_mount
