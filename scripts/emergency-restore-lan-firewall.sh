#!/bin/sh
{
    echo "kindle-sshupstart emergency restore started: $(date)"

    LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"

    iptables -F OUTPUT
    iptables -P OUTPUT ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -d 127.0.0.1/32 -j ACCEPT
    iptables -A OUTPUT -d "$LAN_CIDR" -j ACCEPT
    iptables -A OUTPUT -j REJECT

    mkdir -p /mnt/us/admin-scripts

    cat > /mnt/us/admin-scripts/internet-off.sh <<EOF
#!/bin/sh
iptables -F OUTPUT
iptables -P OUTPUT ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -d 127.0.0.1/32 -j ACCEPT
iptables -A OUTPUT -d ${LAN_CIDR} -j ACCEPT
iptables -A OUTPUT -j REJECT
EOF
    chmod 755 /mnt/us/admin-scripts/internet-off.sh

    iptables -S OUTPUT
    rm -f /mnt/us/emergency.sh
    sync
    echo "kindle-sshupstart emergency restore completed: $(date)"
} >> /mnt/us/emergency-recover.log 2>&1
