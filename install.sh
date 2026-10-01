#!/bin/bash
# Installs airpods-bt-fix. Run: sudo ./install.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
cd "$(dirname "$(readlink -f "$0")")"
DIR=/var/lib/airpods-bt

install -D -m755 airpods-bt-fix /usr/local/sbin/airpods-bt-fix
install -D -m644 airpods-bt-fix.service /etc/systemd/system/airpods-bt-fix.service
command -v restorecon >/dev/null && restorecon /usr/local/sbin/airpods-bt-fix /etc/systemd/system/airpods-bt-fix.service || true
systemctl daemon-reload
systemctl enable airpods-bt-fix.service

if rpm-ostree kargs | grep -q "firmware_class.path=$DIR/fw"; then
  echo "Kernel argument already present"
else
  echo "Adding kernel argument firmware_class.path=$DIR/fw"
  rpm-ostree kargs --append="firmware_class.path=$DIR/fw"
fi

echo "Downloading firmware and building the module (first run takes a few minutes)..."
/usr/local/sbin/airpods-bt-fix --prepare

echo
echo "Done. Shut the computer DOWN (not reboot), wait 10 seconds, power it on."
echo "Check:  journalctl -k -b | grep -i 'RTL:' | tail -3    -> fw version 0xd7c83bcf"
