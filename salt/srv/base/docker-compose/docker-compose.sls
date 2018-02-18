{% set compose_version = '1.11.2' %}
{% set install_path = '/opt/bin/docker-compose' %}
{% set rootfs = '/rootfs' %}

docker-compose-installed:
  cmd.run:
    - name: curl -Lf https://github.com/docker/compose/releases/download/{{ compose_version }}/docker-compose-`uname -s`-`uname -m` > {{ rootfs }}{{ install_path }}
    - unless: {{ rootfs }}{{ install_path }}/docker-compose --version | grep {{ compose_version }}

docker-compose-executable:
  file.managed:
    - name: {{ rootfs }}{{ install_path }}
    - mode: 755
    - require:
      - cmd: docker-compose-installed
