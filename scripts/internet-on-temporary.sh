#!/bin/sh
iptables -F OUTPUT
iptables -P OUTPUT ACCEPT
