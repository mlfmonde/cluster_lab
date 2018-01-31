#!/bin/sh


# minion is preinstalled in the base image
# but is not running
mkdir -p /home/core/salt/pki
echo '{{ vm['priv_key'] }}' > /home/core/salt/pki/minion.pem
echo '{{ vm['pub_key'] }}' > /home/core/salt/pki/minion.pub
cat > /home/core/salt/minion <<EOF
{{minion}}
EOF

# mapping dbus to access to systemctl from container
docker run -d  --privileged \
    --network host \
    -v /home/core/salt:/etc/salt \
    -v /var/run/dbus:/var/run/dbus \
    anybox/salt-minion:2017.7

