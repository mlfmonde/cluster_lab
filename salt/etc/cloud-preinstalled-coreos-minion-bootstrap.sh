#!/bin/sh


# minion is preinstalled in the base image
# but is not running
mkdir -p /home/core/salt/pki
echo '{{ vm['priv_key'] }}' > /home/core/salt/pki/minion.pem
echo '{{ vm['pub_key'] }}' > /home/core/salt/pki/minion.pub
cat > /home/core/salt/minion <<EOF
{{minion}}
EOF

sudo hostnamectl set-hostname '{{ vm['name'] }}'

# mapping dbus to access to systemctl from container
docker run -d  --privileged \
    --network host \
    --restart unless-stopped \
    --name salt-minion \
    -v /lib/systemd/system:/lib/systemd/system \
    -v /usr/lib/systemd/system:/usr/lib/systemd/system \
    -v /etc/systemd/system:/etc/systemd/system \
    -v /home/core/salt:/etc/salt \
    -v /var/run/dbus:/var/run/dbus \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /:/rootfs \
    anybox/salt-minion:2017.7
