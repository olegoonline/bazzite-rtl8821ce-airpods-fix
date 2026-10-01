#!/bin/bash
# Removes airpods-bt-fix completely. Run: sudo ./uninstall.sh
set -u
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
systemctl disable --now airpods-bt-fix.service 2>/dev/null
rm -f /etc/systemd/system/airpods-bt-fix.service /usr/local/sbin/airpods-bt-fix
systemctl daemon-reload
rpm-ostree kargs --delete-if-present="firmware_class.path=/var/lib/airpods-bt/fw"
podman images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost/airpods-bt-builder' | xargs -r podman rmi
rm -rf /var/lib/airpods-bt
echo "Removed. Shut down and power on to return to the stock driver and firmware."
