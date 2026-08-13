#!/bin/sh
echo "--- time ---"
date

echo "--- network ---"
ifconfig wlan0 2>/dev/null | sed -n '1,8p' || true

echo "--- ssh ---"
status koreader-dropbear 2>&1 || true

echo "--- firewall ---"
iptables -S OUTPUT 2>&1 || true
