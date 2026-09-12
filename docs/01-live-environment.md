# 01 — The live environment

You are at `root@archiso ~ #`. `root` means you are the administrator; `#` is the prompt.
Nothing is installed yet.

---

## 1. Make the text readable

The default console font is tiny on a 15" 1080p screen.

```bash
setfont ter-132b
```

Terminus, 32 pixels tall, bold. This only affects the current live session.

---

## 2. Confirm you booted in UEFI mode

```bash
cat /sys/firmware/efi/fw_platform_size
```

| Output | Meaning |
|---|---|
| `64` | Correct — booted in 64-bit UEFI mode |
| `No such file or directory` | You booted in legacy/CSM mode. Go back to BIOS and fix Boot Mode. |

This file only exists when the system booted via UEFI. Everything that follows assumes
UEFI, so do not continue until this prints `64`.

---

## 3. Get online

The installer downloads everything from the internet. This step is not optional.

### Ethernet

Plug it in. DHCP runs automatically. Skip to the connection test.

### Wi-Fi

Unblock the radio first — some laptops start with Wi-Fi soft-blocked:

```bash
rfkill unblock wifi
```

Then open the Wi-Fi control tool. `iwctl` drives **iwd**, the wireless daemon in the
live environment:

```bash
iwctl
```

The prompt changes to `[iwd]#`. Run these one at a time:

```
device list
```

Shows your wireless card's name, usually `wlan0`. Use your actual name below if different.

```
station wlan0 scan
```

Tells the card to look for networks. Prints nothing — that is normal.

```
station wlan0 get-networks
```

Lists what it found.

```
station wlan0 connect "Your Network Name"
```

Prompts for the password. Keep the quotes if the name contains spaces.

```
exit
```

Leaves iwctl.

### Test it

```bash
ping -c 3 archlinux.org
```

`ping` sends small test messages; `-c 3` sends three. Healthy output looks like:

```
64 bytes from 209.126.35.79: icmp_seq=1 ttl=48 time=63.5 ms
3 packets transmitted, 3 received, 0% packet loss
```

If you get `Temporary failure in name resolution`, you are not connected. Redo the
Wi-Fi steps.

> **Prefer the main router over a range extender.** This build was done over a
> `_EXT` extender network and download speeds sat around 60–100 KiB/s, which caused
> repeated mirror timeouts later. An extender roughly halves throughput.

---

## 4. Check the clock

```bash
timedatectl
```

Look for:

```
System clock synchronized: yes
NTP service: active
RTC in local TZ: no
```

The time matters because package downloads are verified with cryptographic signatures,
and a badly wrong clock makes valid signatures look invalid.

> **The live environment always shows UTC.** For India (IST, UTC+5:30), a display of
> `12:17 UTC` means `17:47` local. This is correct and needs no action. You set the real
> timezone later, inside the installed system.
>
> `RTC in local TZ: no` is what you want — the hardware clock stores UTC, which is the
> Linux standard and avoids time jumps.

---

## Checkpoint

Before continuing, all of these should be true:

- [ ] `cat /sys/firmware/efi/fw_platform_size` prints `64`
- [ ] `ping -c 3 archlinux.org` shows 0% packet loss
- [ ] `timedatectl` shows `System clock synchronized: yes`

Continue to [`02-partitioning.md`](02-partitioning.md).
