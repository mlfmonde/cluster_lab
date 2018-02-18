{% set username = "core" %}

cluster:
    git.latest:
        - name: 'https://github.com/petrus-v/cluster'
        - target: /rootfs/home/{{ username }}/cluster
        - rev: master
        - branch: master
