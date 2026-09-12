# 00 — Prerequisites

Everything before the installer boots. Do not skip the backup step.

---

## Before you start

**Keep these instructions on a second device.** Once you boot the Arch USB, the laptop
is a black screen with a text prompt and no browser. A phone works fine.

**This erases both drives completely.** Windows, recovery partitions, personal files,
all of it. Copy anything you want to keep to a USB drive, cloud storage, or another
computer first.

**Expect it to take a while.** A first manual install with things going wrong is
realistically an evening, not an hour.

---

## 1. Download the ISO

An **ISO** is a disk image: one file containing a complete bootable system.

1. Go to <https://archlinux.org/download/>
2. Scroll to the mirror list and pick one in or near your country
3. Download `archlinux-YYYY.MM.DD-x86_64.iso`
4. Note the **SHA256 checksum** shown on the download page

### Verify the download

A checksum is a fingerprint of a file. If one byte is corrupted the fingerprint will
not match, and a corrupted ISO causes strange errors much later in the install.

**Windows (PowerShell, in your Downloads folder):**

```powershell
Get-FileHash .\archlinux-YYYY.MM.DD-x86_64.iso -Algorithm SHA256
```

**Linux / macOS:**

```bash
sha256sum archlinux-YYYY.MM.DD-x86_64.iso
```

Compare against the checksum on the website. If they differ, download again.

---

## 2. Write the USB

You need a USB stick of 2 GB or more. It will be wiped.

### Windows — Rufus

Download from <https://rufus.ie/>.

1. Plug in the USB and open Rufus
2. **Device** → your USB stick (check the size, twice)
3. **Boot selection** → SELECT → the Arch ISO
4. **Partition scheme** → `GPT`
5. **Target system** → `UEFI (non CSM)`
6. **START** → when asked about image mode, choose **DD Image mode**

DD mode copies the ISO byte-for-byte and is the most reliable option for Arch.

### Linux — dd

Find the USB device name first:

```bash
lsblk
```

`lsblk` lists block devices. Identify your USB by its size — it will be something
like `sdb`. Then:

```bash
sudo dd bs=4M if=archlinux-YYYY.MM.DD-x86_64.iso of=/dev/sdX status=progress oflag=sync
```

| Flag | Meaning |
|---|---|
| `if=` | input file (the ISO) |
| `of=` | output device — **replace `sdX` with your USB** |
| `bs=4M` | copy in 4 MB blocks, faster |
| `status=progress` | show progress |
| `oflag=sync` | flush everything to the device before finishing |

> **Getting `of=` wrong wipes the wrong drive with no confirmation and no undo.**
> Run `lsblk` again immediately before pressing Enter.

---

## 3. BIOS / UEFI settings

The firmware runs before any operating system. To enter it, restart and repeatedly tap
the setup key as the machine powers on.

**On an Acer Aspire E5-575G:**

| Key | Function |
|---|---|
| `F2` | Enter BIOS setup |
| `F12` | One-time boot menu |
| `F10` | Save and exit |
| `F5` / `F6` | Move an item up/down in the boot order |

### Settings to change

| Setting | Tab | Value | Why |
|---|---|---|---|
| Boot Mode | Boot | `UEFI` | Not Legacy/CSM. The whole install is built for UEFI. |
| Secure Boot | Boot | `Disabled` | Only allows firmware-approved bootloaders; Arch is not signed for it. |
| SATA Mode | Information | `AHCI` | If set to RAID or Intel RST, Linux may not see the SSD at all. |
| Supervisor Password | Security | **Set one** | On Acer, several boot and security options are greyed out until a supervisor password exists. |

> **Set the supervisor password before anything else.** Secure Boot cannot be toggled
> without it on this firmware. Remember it — you will need it again.

Verify on the **Information** tab that your drives are detected:

```
HDD0 Model Name:   KINGSTON SNV2S500G
HDD1 Model Name:   (your HDD, if listed)
SATA Mode:         AHCI
Total Memory:      4096 MB
```

Press `F10` to save and exit.

---

## 4. Boot the USB

Restart and tap `F12` for the boot menu. Select the USB device. On the Arch menu choose
the first entry, **Arch Linux install medium (x86_64, UEFI)**.

After some scrolling text you land at:

```
root@archiso ~ #
```

That is the **live environment** — a temporary Arch system running entirely from the USB.
Nothing has touched your drives yet.

Continue to [`01-live-environment.md`](01-live-environment.md).

---

## Things that went wrong here

**Secure Boot re-enabled itself after a full power-off.** Several days into the build,
a cold shutdown brought back a `Security Boot Fail` padlock screen. Nothing was damaged;
Acer firmware restored Secure Boot to enabled on its own. Fix: `F2` → Boot →
Secure Boot → Disabled → `F10`. If this recurs on every power-off, suspect a weak CMOS
battery, or look into signing the bootloader with `sbctl` so Secure Boot can stay on.

**The USB installer menu is not your installed system.** After a failed boot attempt,
seeing "Arch Linux install medium" means the USB is still plugged in and the firmware
fell back to it. Remove the USB as the screen goes black on reboot.
