{% set compose_version = '1.20.1' %}
{% set compose_path = '/opt/bin/docker-compose' %}
{% set rootfs = '/rootfs' %}

docker-compose-installed:
  cmd.run:
    - name: curl -Lf https://github.com/docker/compose/releases/download/{{ compose_version }}/docker-compose-`uname -s`-`uname -m` > {{ rootfs }}{{ compose_path }}
    - unless: {{ rootfs }}{{ compose_path }} --version | grep {{ compose_version }}

docker-compose-executable:
  file.managed:
    - name: {{ rootfs }}{{ compose_path }}
    - mode: 755
    - require:
      - cmd: docker-compose-installed
