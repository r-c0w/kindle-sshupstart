#!/bin/sh
set -eu

if [ "$(id -u)" != "0" ]; then
    echo "This uninstaller must run as root on the Kindle." >&2
    exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/mnt/us/recovery-backups/kindle-sshupstart-uninstall-${TS}"
mkdir -p "$BACKUP_DIR"

backup_if_present() {
    if [ -e "$1" ]; then
        cp -p "$1" "$BACKUP_DIR/"
    fi
}

backup_if_present /etc/upstart/koreader-dropbear.conf
backup_if_present /etc/upstart/kindle-local-firewall.conf
backup_if_present /var/local/dropbear/authorized_keys

stop koreader-dropbear >/dev/null 2>&1 || true

mntroot rw
rm -f /etc/upstart/koreader-dropbear.conf
rm -f /etc/upstart/kindle-local-firewall.conf
mntroot ro

iptables -F OUTPUT
iptables -P OUTPUT ACCEPT

echo "Uninstalled kindle-sshupstart boot jobs."
echo "Backup: $BACKUP_DIR"
echo "Outbound firewall is now open."
