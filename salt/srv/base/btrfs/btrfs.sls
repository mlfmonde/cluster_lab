{% set rootfs = '/rootfs' %}
{% set dev1 = '/dev/vdb' %}
{% set dev2 = '/dev/vdc' %}
{% set btrfs_volumes_dir = '/var/lib/buttervolume/volumes' %}
{% set btrfs_snapshots_dir = '/var/lib/buttervolume/snapshots' %}
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

btrfs_systemd_mount_unit_snapshots:
  file.managed:
    - name: {{ rootfs }}/etc/systemd/system/var-lib-buttervolume-snapshots.mount
    - source: salt://btrfs/btrfs-subvolume.mount.jinja
    - template: jinja
    - defaults:
        subvolume: snapshots
        device: {{ dev1 }}
        mount_point: {{ btrfs_snapshots_dir }}

btrfs_systemd_mount_unit_volumes:
  file.managed:
    - name: {{ rootfs }}/etc/systemd/system/var-lib-buttervolume-volumes.mount
    - source: salt://btrfs/btrfs-subvolume.mount.jinja
    - template: jinja
    - defaults:
        subvolume: volumes
        device: {{ dev1 }}
        mount_point: {{ btrfs_volumes_dir }}

btrfs_subvolume_mount_snapshots:
  service.running:
    - name: var-lib-buttervolume-snapshots.mount
    - enable: True
    - reload: True
    - onchanges:
      - file: btrfs_systemd_mount_unit_snapshots

btrfs_subvolume_mount_volumes:
  service.running:
    - name: var-lib-buttervolume-volumes.mount
    - enable: True
    - reload: True
    - onchanges:
      - file: btrfs_systemd_mount_unit_volumes
