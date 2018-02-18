{% set rootfs = '/rootfs' %}
{% set dev1 = '/dev/vdb' %}
{% set dev2 = '{{ dev2 }}' %}
{% set btrfs_volumes_dir = '/var/lib/docker/volumes' %}
{% set btrfs_snapshots_dir = '/var/lib/docker/snapshots' %}

btrfs_format:
  cmd.run:
    - name: mkfs.btrfs -f {{ dev1 }} {{ dev2 }}
    - unless: btrfs device ready {{ dev1 }}

btrfs_mount_local:
  mount.mounted:
    - name: /mnt/local
    - device: {{ dev1 }}
    - fstype: btrfs
    - mkmnt: True
    - require:
      - cmd: btrfs_format

btrfs_subvolume_create_snapshots:
  cmd.run:
    - name: btrfs subvolume create /mnt/local/snapshots
    - unless: btrfs subvolume show /mnt/local/snapshots
    - require:
      - mount: btrfs_mount_local

btrfs_subvolume_create_volumes:
  cmd.run:
    - name: btrfs subvolume create /mnt/local/volumes
    - unless: btrfs subvolume show /mnt/local/volumes
    - require:
      - mount: btrfs_mount_local

btrfs_systemd_mount_unit_snapshots:
  file.managed:
    - name: /rootfs/etc/systemd/system/var-lib-docker-snapshots.mount
    - source: salt://btrfs/var-lib-docker-snapshots.mount.jinja
    - template: jinja
    - defaults:
        device: {{ dev1 }}
        mount_point: {{ btrfs_snapshots_dir }}

btrfs_systemd_mount_unit_volumes:
  file.managed:
    - name: /rootfs/etc/systemd/system/var-lib-docker-volumes.mount
    - source: salt://btrfs/var-lib-docker-volumes.mount.jinja
    - template: jinja
    - defaults:
        device: {{ dev1 }}
        mount_point: {{ btrfs_volumes_dir }}

btrfs_reload_systemd:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: btrfs_systemd_mount_unit_snapshots
        - file: btrfs_systemd_mount_unit_volumes

btrfs_subvolume_mount_snapshots:
  cmd.run:
    - name: systemctl start var-lib-docker-snapshots.mount
    - unless:
      - systemctl status var-lib-docker-snapshots.mount
    - require:
      - file: btrfs_systemd_mount_unit_snapshots

btrfs_subvolume_mount_volumes:
  cmd.run:
    - name: systemctl start var-lib-docker-volumes.mount
    - unless:
      - systemctl status var-lib-docker-volumes.mount
    - require:
      - file: btrfs_systemd_mount_unit_volumes


# btrfs_umount_local:
#   mount.unmounted:
#     - name: /mnt/local
#     - device: {{ dev1 }}
#     - require:
#       - cmd: btrfs_subvolume_create_snapshots
#       - cmd: btrfs_subvolume_create_volumes

