# kindle-sshupstart

Boot-time SSH and local-only networking for already-jailbroken Kindles.

This project installs a small, reversible setup that:

- starts KOReader's bundled Dropbear SSH server at boot
- uses SSH public-key authentication
- keeps local LAN access working
- blocks ordinary outbound internet traffic by default

It does not include a jailbreak, exploit, firmware, Amazon registration bypass, or any Amazon credentials.

## Tested Scope

- Kindle Basic 2024 / 11th generation style device w/ MTP storage
- Firmware 5.18.6
- Vera/KPM jailbreak stack
- KOReader v2026.07.1
- KOReader bundled Dropbear
- WPA2 Wi-Fi with a `192.168.1.0/24` or similar home LAN

Other Kindle models, firmware versions, jailbreak stacks, and KOReader versions may work, but should be treated as untested until someone verifies them.

## Requirements

- A Kindle you own and have already jailbroken
- Root shell access on the Kindle
- KOReader installed at `/mnt/us/koreader`
- KOReader Dropbear available at `/mnt/us/koreader/dropbear`
- An SSH public key from your computer

## Network Model

The default firewall is local-only:

- loopback is allowed
- a configured LAN CIDR is allowed, for example `192.168.1.0/24`
- all other outbound IP traffic is rejected

This means the Kindle may show Wi-Fi as having no internet. That is intentional. Local SSH should still work.

The installer tries to auto-detect the LAN CIDR from the Kindle's current `wlan0` IPv4 address. For example, `192.168.1.42` becomes `192.168.1.0/24`.

That CIDR is then baked into:

- `/etc/upstart/kindle-local-firewall.conf`
- `/mnt/us/admin-scripts/internet-off.sh`

If your network changes later, rerun the installer with the new `--lan-cidr`, or edit those two files manually.

If auto-detection fails, the installer falls back to `192.168.1.0/24`.

## Internet Toggle Scripts

`internet-off.sh` restores the protective local-only firewall:

- local LAN remains reachable
- SSH from your computer remains reachable
- outbound internet is rejected

`internet-on-temporary.sh` flushes the outbound firewall and allows normal internet access until:

- `internet-off.sh` is run again
- the Kindle reboots and the Upstart firewall job reapplies
- another firewall script changes the rules

Use `internet-on-temporary.sh` carefully. It may allow Amazon services to connect while it is active.

## Quick Start

Copy this repository to the Kindle, or copy only `install.sh` plus the `files/` and `scripts/` directories.

Run as root on the Kindle:

```sh
sh install.sh --pubkey "ssh-ed25519 AAAA... your-key"
```

Or provide the LAN CIDR explicitly:

```sh
sh install.sh --lan-cidr 192.168.1.0/24 --pubkey "ssh-ed25519 AAAA... your-key"
```

Then connect from your computer:

```sh
ssh -p 2222 root@KINDLE_IP
```

If your key is not loaded into your SSH agent:

```sh
ssh -i ~/.ssh/your_key -p 2222 root@KINDLE_IP
```

## Expected Status Output

After installation, `status.sh` should show the Wi-Fi interface, the boot SSH job, and firewall rules similar to:

```text
--- network ---
wlan0     Link encap:Ethernet  HWaddr ...
          inet addr:192.168.1.42  Bcast:192.168.1.255  Mask:255.255.255.0

--- ssh ---
koreader-dropbear start/running, process 1234

--- firewall ---
-P OUTPUT ACCEPT
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -d 127.0.0.1/32 -j ACCEPT
-A OUTPUT -d 192.168.1.0/24 -j ACCEPT
-A OUTPUT -j REJECT --reject-with icmp-port-unreachable
```

## Files Installed

- `/etc/upstart/koreader-dropbear.conf`
- `/etc/upstart/kindle-local-firewall.conf`
- `/var/local/dropbear/authorized_keys`
- `/var/local/dropbear/dropbear_ed25519_host_key`
- `/mnt/us/admin-scripts/internet-off.sh`
- `/mnt/us/admin-scripts/internet-on-temporary.sh`
- `/mnt/us/admin-scripts/status.sh`

Backups are written to:

```text
/mnt/us/recovery-backups/kindle-sshupstart-YYYYMMDD-HHMMSS/
```

## Recovery

If you lose SSH but USB/MTP storage is available, copy `scripts/emergency-restore-lan-firewall.sh` to the top of Kindle storage as:

```text
/mnt/us/emergency.sh
```

Then reboot or wait for the jailbreak emergency hook to run it.

The emergency script uses `192.168.1.0/24` by default. If your LAN uses a different subnet, edit the script before copying it, or set `LAN_CIDR` inside the script.

## Uninstall

Run as root:

```sh
sh uninstall.sh
```

The uninstaller disables the boot jobs created by this project and restores an open outbound firewall. It does not remove KOReader.

## Warnings

This changes files under `/etc/upstart` and `/var/local`. Read the scripts before running them.

Do not run this on a device you do not own.

This is not a substitute for a known-good jailbreak recovery path.

Use at your own risk.

## Known Risks

- A wrong LAN CIDR can block SSH replies from reaching your computer.
- A missing or moved KOReader Dropbear binary will prevent boot SSH from starting.
- Firmware updates may change Upstart jobs, firewall behavior, or KOReader paths.
- `internet-on-temporary.sh` intentionally allows outbound internet until disabled or rebooted.
- If USB/MTP is unavailable and SSH is blocked, recovery may require device-specific jailbreak recovery steps.
