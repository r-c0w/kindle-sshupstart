#!/bin/sh
set -eu

LAN_CIDR=""
DEFAULT_LAN_CIDR="192.168.1.0/24"
SSH_PORT="2222"
PUBKEY=""
DROPBEAR="/mnt/us/koreader/dropbear"
KOREADER_HOST_KEY="/mnt/us/koreader/settings/SSH/dropbear_ed25519_host_key"
DROPBEAR_DIR="/var/local/dropbear"
BACKUP_ROOT="/mnt/us/recovery-backups"
ADMIN_DIR="/mnt/us/admin-scripts"

usage() {
    cat <<EOF
Usage:
  sh install.sh --pubkey "ssh-ed25519 AAAA..." [--lan-cidr 192.168.1.0/24] [--port 2222]

Options:
  --pubkey    SSH public key allowed to log in as root. Required.
  --lan-cidr  Local network CIDR to allow. Default: auto-detect from wlan0, fallback ${DEFAULT_LAN_CIDR}
  --port      SSH listen port. Default: ${SSH_PORT}
EOF
}

detect_lan_cidr() {
    IP="$(ifconfig wlan0 2>/dev/null | awk '/inet addr:/ { sub(/addr:/, "", $2); print $2; exit }')"
    if [ -n "$IP" ]; then
        echo "$IP" | awk -F. 'NF == 4 { printf "%s.%s.%s.0/24\n", $1, $2, $3 }'
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --lan-cidr)
            LAN_CIDR="$2"
            shift 2
            ;;
        --port)
            SSH_PORT="$2"
            shift 2
            ;;
        --pubkey)
            PUBKEY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$(id -u)" != "0" ]; then
    echo "This installer must run as root on the Kindle." >&2
    exit 1
fi

if [ -z "$PUBKEY" ]; then
    echo "--pubkey is required." >&2
    exit 1
fi

case "$PUBKEY" in
    ssh-rsa\ *|ssh-ed25519\ *|ecdsa-sha2-*\ *)
        ;;
    *)
        echo "The --pubkey value does not look like an SSH public key." >&2
        exit 1
        ;;
esac

if [ ! -x "$DROPBEAR" ]; then
    echo "KOReader Dropbear was not found at $DROPBEAR." >&2
    exit 1
fi

if [ -z "$LAN_CIDR" ]; then
    LAN_CIDR="$(detect_lan_cidr || true)"
fi

if [ -z "$LAN_CIDR" ]; then
    LAN_CIDR="$DEFAULT_LAN_CIDR"
    echo "Could not auto-detect wlan0 CIDR; falling back to $LAN_CIDR." >&2
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/kindle-sshupstart-${TS}"
mkdir -p "$BACKUP_DIR" "$DROPBEAR_DIR" "$ADMIN_DIR"

backup_if_present() {
    if [ -e "$1" ]; then
        cp -p "$1" "$BACKUP_DIR/"
    fi
}

backup_if_present /etc/upstart/koreader-dropbear.conf
backup_if_present /etc/upstart/kindle-local-firewall.conf
backup_if_present "${DROPBEAR_DIR}/authorized_keys"
backup_if_present "${DROPBEAR_DIR}/dropbear_ed25519_host_key"

printf '%s\n' "$PUBKEY" > "${DROPBEAR_DIR}/authorized_keys"
chmod 600 "${DROPBEAR_DIR}/authorized_keys"

if [ -f "$KOREADER_HOST_KEY" ]; then
    cp -p "$KOREADER_HOST_KEY" "${DROPBEAR_DIR}/dropbear_ed25519_host_key"
else
    echo "KOReader host key not found at $KOREADER_HOST_KEY." >&2
    echo "Start KOReader SSH once, then rerun this installer." >&2
    exit 1
fi
chmod 600 "${DROPBEAR_DIR}/dropbear_ed25519_host_key"

mntroot rw

sed \
    -e "s|@DROPBEAR@|${DROPBEAR}|g" \
    -e "s|@DROPBEAR_DIR@|${DROPBEAR_DIR}|g" \
    -e "s|@SSH_PORT@|${SSH_PORT}|g" \
    files/koreader-dropbear.conf.template > /etc/upstart/koreader-dropbear.conf

sed \
    -e "s|@LAN_CIDR@|${LAN_CIDR}|g" \
    files/kindle-local-firewall.conf.template > /etc/upstart/kindle-local-firewall.conf

chmod 0644 /etc/upstart/koreader-dropbear.conf /etc/upstart/kindle-local-firewall.conf

mntroot ro

sed -e "s|@LAN_CIDR@|${LAN_CIDR}|g" scripts/internet-off.sh.template > "${ADMIN_DIR}/internet-off.sh"
cp scripts/internet-on-temporary.sh "${ADMIN_DIR}/internet-on-temporary.sh"
cp scripts/status.sh "${ADMIN_DIR}/status.sh"
chmod 755 "${ADMIN_DIR}/internet-off.sh" "${ADMIN_DIR}/internet-on-temporary.sh" "${ADMIN_DIR}/status.sh"

"${ADMIN_DIR}/internet-off.sh"

if status koreader-dropbear >/dev/null 2>&1; then
    restart koreader-dropbear >/dev/null 2>&1 || true
else
    start koreader-dropbear >/dev/null 2>&1 || true
fi

echo "Installed kindle-sshupstart."
echo "Backup: $BACKUP_DIR"
echo "LAN allowed: $LAN_CIDR"
echo "SSH port: $SSH_PORT"
echo
"${ADMIN_DIR}/status.sh"
