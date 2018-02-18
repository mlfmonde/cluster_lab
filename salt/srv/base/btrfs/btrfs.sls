btrfs_format:
  cmd.run:
    - name: mkfs.btrfs -f /dev/vdb /dev/vdc
    - unless: btrfs device ready /dev/vdb

btrfs_mount_local:
  mount.mounted:
    - name: /mnt/local
    - device: /dev/vdb
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
    - source: salt://btrfs/var-lib-docker-snapshots.mount

btrfs_systemd_mount_unit_volumes:
  file.managed:
    - name: /rootfs/etc/systemd/system/var-lib-docker-volumes.mount
    - source: salt://btrfs/var-lib-docker-volumes.mount

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

btrfs_subvolume_mount_volumes:
  cmd.run:
    - name: systemctl start var-lib-docker-volumes.mount
    - unless:
      - systemctl status var-lib-docker-volumes.mount


# btrfs_umount_local:
#   mount.unmounted:
#     - name: /mnt/local
#     - device: /dev/vdb
#     - require:
#       - cmd: btrfs_subvolume_create_snapshots
#       - cmd: btrfs_subvolume_create_volumes

