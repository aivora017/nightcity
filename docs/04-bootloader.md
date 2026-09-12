# 04 — Bootloader (and the Acer firmware saga)

The longest chapter, because this is where the build nearly died. If you have an Acer
Aspire E5-575G or similar InsydeH20 firmware, read the whole thing before starting.

---

## Why systemd-boot

| | systemd-boot | GRUB |
|---|---|---|
| Installation | Already part of systemd — nothing to install | Separate package |
| Config | Two tiny text files | Generated script, more moving parts |
| Firmware support | UEFI only | UEFI and legacy BIOS |
| Complexity | Minimal | Considerable |

UEFI-only is fine here, so systemd-boot wins on simplicity.

---

## 1. Install it

Run this **inside the chroot**:

```bash
bootctl install
```

Expected output includes:

```
Created directory "/boot/EFI"
Created directory "/boot/EFI/systemd"
Created directory "/boot/EFI/BOOT"
Created directory "/boot/loader"
Created directory "/boot/loader/entries"
Copied "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" to "/boot/EFI/systemd/systemd-bootx64.efi"
Copied "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" to "/boot/EFI/BOOT/BOOTX64.EFI"
Not booted with EFI or running in a container, skipping EFI variable modifications.
```

> **That last line is the entire problem.**
>
> Inside a chroot, `bootctl` refuses to write to firmware NVRAM. It copies the bootloader
> files onto the ESP correctly, but the firmware is never told they exist. This is why the
> first boot attempt gives **"No Bootable Device"** even though everything on disk is
> perfect.
>
> Two warnings about `random-seed` being world-accessible are harmless — FAT32 has no Unix
> permissions.

> **`bootctl install` recreates `/boot/loader/entries` as an empty directory.** If you
> already wrote your `.conf` entries and then run `bootctl install` again, **they are
> gone**. Write the entries *after* the final `bootctl install`.

---

## 2. Get the root UUID

```bash
blkid -s UUID -o value /dev/nvme0n1p2
```

On this machine: `60b574aa-ec76-4f3e-8ab7-d16e79806ce6`

The bootloader needs to know which filesystem holds the system. Use the UUID rather than
`/dev/nvme0n1p2` because device names can shift.

---

## 3. Loader configuration

```bash
cat > /boot/loader/loader.conf << 'EOF'
default arch.conf
timeout 3
console-mode max
editor no
EOF
```

| Setting | Meaning |
|---|---|
| `default` | Which entry boots if you press nothing |
| `timeout 3` | Show the menu for three seconds — long enough to pick the LTS kernel if the main one breaks |
| `console-mode max` | Use the highest available resolution |
| `editor no` | Disable editing kernel parameters at boot. Leaving it on is a security hole: anyone with physical access could boot to a root shell |

Quoting `'EOF'` prevents variable expansion, which you do not want here.

---

## 4. Boot entries

Generate these with command substitution so the UUID is inserted automatically — no manual
transcription, no typos:

```bash
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value /dev/nvme0n1p2) rootflags=subvol=@ rw
EOF
```

```bash
cat > /boot/loader/entries/arch-lts.conf << EOF
title   Arch Linux LTS
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts.img
options root=UUID=$(blkid -s UUID -o value /dev/nvme0n1p2) rootflags=subvol=@ rw
EOF
```

How `cat > file << EOF` works: everything up to the `EOF` marker is written into the file.
`$(...)` runs that command and substitutes its output.

| Line | Meaning |
|---|---|
| `linux /vmlinuz-linux` | Kernel image. Paths are relative to `/boot` |
| `initrd /intel-ucode.img` | CPU microcode. **Must come before the initramfs line** |
| `initrd /initramfs-linux.img` | Initial ramdisk — a minimal environment that loads the drivers needed to reach the real root filesystem, including the Btrfs module |
| `rootflags=subvol=@` | **Essential.** Without it the kernel mounts the top of the Btrfs filesystem instead of the `@` subvolume, and the boot fails |
| `rw` | Mount root read-write |

The LTS entry is your insurance policy. If a kernel update ever leaves the machine
unbootable, pick it at the menu and you are back in.

### Add `pci=noaer` (optional but recommended on this hardware)

If your Wi-Fi card floods the console with
`ath10k_pci 0000:03:00.0: AER: Error of this Agent is reported first`, append `pci=noaer`
to the end of the `options` line in **both** entries. See
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md#ath10k-aer-errors-flooding-the-console).

---

## 5. Verify

```bash
cat /boot/loader/entries/arch.conf
cat /boot/loader/entries/arch-lts.conf
ls /boot/loader/entries/
bootctl list
ls /boot
```

Check character by character:

- `arch.conf` says `Arch Linux`, `vmlinuz-linux`, `initramfs-linux.img` — **no** `-lts`
- `arch-lts.conf` says `Arch Linux LTS` and everything has `-lts`
- Both middle lines say **`initrd`** — i-n-i-t-r-d
- The UUID is present as an actual value, not the literal text `$(blkid...)`
- `ls /boot/loader/entries/` shows **exactly two files**, both ending `.conf`
- `ls /boot` shows `vmlinuz-linux`, `vmlinuz-linux-lts`, `initramfs-linux.img`,
  `initramfs-linux-lts.img`, `intel-ucode.img`, plus `EFI` and `loader`

> `bootctl list` will print *"Not booted with EFI or running in a container"* inside the
> chroot. That is expected and does not affect the entries themselves.

### Quick repairs

If `arch.conf` accidentally contains the LTS content:

```bash
sed -i 's/-lts//g; s/ LTS//' /boot/loader/entries/arch.conf
```

If you created files with a typo'd extension (`arch.cong`):

```bash
rm /boot/loader/entries/arch.cong /boot/loader/entries/arch-lts.cong
```

---

## 6. The Acer firmware saga

Everything above is correct and standard. On most machines you would now reboot into a
working system. On this Acer, four attempts failed first.

### Attempt 1 — `bootctl install` from the chroot

**Result:** `No Bootable Device`

**Why:** the `skipping EFI variable modifications` message. Files on disk, firmware
unaware.

### Attempt 2 — the BOOTX64.EFI fallback

UEFI has a hardcoded rule: if no boot entry is registered, look for
`\EFI\BOOT\BOOTX64.EFI` on the ESP. This is the removable-media fallback, and
`bootctl install` creates it automatically.

Verified present and the right size:

```bash
ls -la /boot/EFI/BOOT/BOOTX64.EFI
-rwxr-xr-x 1 root root 160256 Sep 11 02:10 /boot/EFI/BOOT/BOOTX64.EFI
```

**Result:** `No Bootable Device`

**Why:** this firmware ignores the fallback path for internal drives.

### Attempt 3 — `efibootmgr` from the live environment

The key insight: `bootctl` refuses to write NVRAM *inside a chroot*, but the live USB
itself boots in UEFI mode. Run `efibootmgr` from the live environment **outside** the
chroot and it has full firmware access.

```bash
mount -o subvol=@ /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot
efibootmgr
```

This confirmed real access:

```
BootCurrent: 0001
BootOrder: 2001,2002,2003
Boot0000* Unknown Device: KINGSTON SNV2S500G   PciRoot(0x0)/...
Boot0001* USB HDD: SanDisk                     PciRoot(0x0)/...
Boot2001* EFI USB Device
Boot2002* EFI DVD/CDROM
Boot2003* EFI Network
```

Note `BootOrder` contains only generic USB / DVD / Network entries. The SSD is not in the
order at all, so the firmware never tries it.

Created the entry:

```bash
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Arch Linux" \
  --loader '\EFI\systemd\systemd-bootx64.efi' --unicode
```

| Flag | Meaning |
|---|---|
| `--disk` | The drive, **no** partition number |
| `--part 1` | The EFI partition |
| `--loader` | Path *inside* the ESP. Backslashes are UEFI convention; single quotes stop the shell eating them |
| `--unicode` | Handle the label as UCS-2 |

It worked perfectly:

```
BootOrder: 0002,2001,2002,2003
Boot0002* Arch Linux  HD(1,GPT,1a6bece9-...)/\EFI\systemd-bootx64.efi
```

**Result:** `No Bootable Device`

**Why — and this is the crucial finding:** on the next boot into the live environment,
`efibootmgr` showed **`Boot0002` was gone**. The slot had been freed and was reused by the
next entry created.

> **Acer InsydeH20 firmware silently purges UEFI boot entries it does not recognise, on
> every boot.** The entry was created correctly and then deleted by the firmware before it
> was ever used.

### Attempt 4 — the BIOS "trusted UEFI file" option

Security tab → *Select an UEFI file as trusted for executing*.

**Blocked:** this option lives in a Secure Boot submenu and is only selectable when
Secure Boot is **enabled** — which defeats the purpose, since that is what blocks an
unsigned bootloader in the first place.

### What worked — the Microsoft path

Put systemd-boot where the firmware already looks for Windows.

```bash
# from the live environment
mount -o subvol=@ /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot

mkdir -p /mnt/boot/EFI/Microsoft/Boot
cp /mnt/boot/EFI/systemd/systemd-bootx64.efi \
   /mnt/boot/EFI/Microsoft/Boot/bootmgfw.efi

efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "Windows Boot Manager" \
  --loader '\EFI\Microsoft\Boot\bootmgfw.efi' --unicode

efibootmgr -v          # confirm the entry and BootOrder
ls -la /mnt/boot/EFI/Microsoft/Boot/bootmgfw.efi   # should be ~160256 bytes

umount -R /mnt
reboot
```

**Why this works:** the firmware has a hardcoded search for
`\EFI\Microsoft\Boot\bootmgfw.efi`. It does not verify the file is actually Windows — it
just executes it. So it launches systemd-boot instead. Because this path is one the
firmware auto-detects, it regenerates the entry itself rather than purging it.

Naming the entry "Windows Boot Manager" is deliberate: some Acer firmware matches on the
label as well as the path.

**Result:** boots.

The systemd-boot menu still says "Arch Linux" — the label is only what the *firmware*
calls the file; the menu text comes from your `.conf` entries.

---

## 7. Exit and reboot

```bash
exit                 # leave the chroot
umount -R /mnt       # note the dash; -R unmounts recursively, deepest first
reboot
```

> **Do not skip the unmount.** `/boot` is FAT32 and files you just copied may still be in
> a write cache. An unclean shutdown can leave a truncated bootloader.
>
> If `umount -R /mnt` says `target is busy`, run `cd /` first and retry.

**Pull the USB out as the screen goes black.** If you leave it in, the firmware may boot
back into the installer.

### Expected sequence

1. Acer logo
2. systemd-boot menu listing *Arch Linux* and *Arch Linux LTS*, for three seconds
3. Scrolling boot messages
4. `nightcity login:`

---

## 8. If the boot entry disappears again

It can. Acer firmware has already demonstrated the behaviour. Recovery takes two minutes
and requires no reinstall:

```bash
# boot the USB, then:
mount -o subvol=@ /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot

efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "Windows Boot Manager" \
  --loader '\EFI\Microsoft\Boot\bootmgfw.efi' --unicode

umount -R /mnt
reboot
```

If it recurs frequently, the durable fix is enrolling your own Secure Boot keys with
[`sbctl`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#sbctl)
and signing the bootloader, so Secure Boot can stay enabled and still boot your system.

---

## Reference

- [Arch Wiki — systemd-boot](https://wiki.archlinux.org/title/Systemd-boot)
- [Arch Wiki — Unified Extensible Firmware Interface](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface)
- [Arch Wiki — Secure Boot](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)

Continue to [`05-post-install.md`](05-post-install.md).
