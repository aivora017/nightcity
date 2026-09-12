# nightcity

A cyberpunk Arch Linux rice, built from scratch on a 2016 Acer Aspire E5-575G with
4 GB of RAM — and documented in full, including every mistake.

This repository is two things at once:

1. **My dotfiles.** Configs for Hyprland, Waybar, Kitty and the rest, deployed with GNU Stow.
2. **A complete build log.** Every command, every error, and every fix, written down so
   someone else can follow the same path on similar hardware.

If you are here for the walkthrough, start at [`docs/00-prerequisites.md`](docs/00-prerequisites.md).
If something is broken, go straight to [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

---

## Why this exists

Most Arch install guides assume everything works. This one was written while things
did not work. The Acer firmware refused to boot the bootloader four separate ways.
The AUR helper installed a binary linked against the wrong library version. The
touchpad reported finger contact but no coordinates. Mirrors stalled mid-download.

All of that is documented, because those are the parts a guide normally skips and
they are exactly where a first-time installer gets stuck.

---

## The hardware

| Component | Detail |
|---|---|
| Model | Acer Aspire E5-575G |
| Firmware | InsydeH20 Setup Utility, BIOS v1.12 |
| CPU | Intel Core i5-7200U @ 2.50 GHz (Kaby Lake, 2 cores / 4 threads) |
| RAM | 4 GB |
| GPU (used) | Intel HD Graphics 620 |
| GPU (unused) | NVIDIA GeForce 940MX 2 GB — see note below |
| SSD | Kingston SNV2S500G, 500 GB NVMe (`nvme0n1`) |
| HDD | Toshiba MQ01ABD100, 1 TB SATA (`sda`) |
| Wi-Fi | Qualcomm Atheros, `ath10k` driver |
| Touchpad | ELAN0501:00 04F3:3019, I2C |
| Optical | Slimtype DVD A DA8AESH (unused) |

**On the NVIDIA 940MX:** it is a Maxwell-generation card, and current NVIDIA drivers
have dropped support for that generation. Driving a Wayland compositor through an old
hybrid-graphics setup is a well-known source of pain. This build runs entirely on the
Intel iGPU, which handles Hyprland's blur and animations without complaint. The 940MX
is simply left alone.

**On 4 GB of RAM:** this is the real constraint. Hyprland plus a bar sits around
400–600 MB. The browser is what hurts. zram (compressed swap in RAM) is doing a lot of
heavy lifting here — see [`docs/05-post-install.md`](docs/05-post-install.md).

---

## Disk layout

**SSD — `/dev/nvme0n1`**

| Partition | Size | Format | Mount |
|---|---|---|---|
| `nvme0n1p1` | 1 GB | FAT32 | `/boot` (EFI System Partition) |
| `nvme0n1p2` | ~464.8 GB | Btrfs | `/` and friends, via subvolumes |

**Btrfs subvolumes on `nvme0n1p2`**

| Subvolume | Mounted at | Why separate |
|---|---|---|
| `@` | `/` | the system — this is what you roll back |
| `@home` | `/home` | your files, excluded from system rollbacks |
| `@snapshots` | `/.snapshots` | where Snapper stores snapshots |
| `@log` | `/var/log` | excluded so a rollback does not erase evidence of what broke |
| `@pkg` | `/var/cache/pacman/pkg` | package cache, no point snapshotting |

Mount options: `noatime,compress=zstd:3,ssd,discard=async,space_cache=v2`

**HDD — `/dev/sda`**

| Partition | Size | Format | Mount |
|---|---|---|---|
| `sda1` | 931.5 GB | ext4 | `/data` — media, wallpapers, backups |

**Swap:** none on disk. zram provides ~7.4 GB of compressed swap inside RAM.
This trades away hibernation for speed and reduced SSD wear. A swap file can be
added later if hibernation becomes necessary.

---

## The software stack

| Role | Choice |
|---|---|
| Bootloader | systemd-boot (installed at the Microsoft path — see below) |
| Kernels | `linux` (primary) + `linux-lts` (fallback) |
| Compositor | Hyprland (Wayland) |
| Terminal | Kitty |
| Launcher | Wofi |
| Bar | Waybar |
| Shell | Zsh |
| Browser | Firefox |
| Audio | PipeWire + WirePlumber |
| Network | NetworkManager |
| Snapshots | Snapper + snap-pac |
| AUR helper | paru (**built from source, not `paru-bin`**) |
| Power | TLP |
| Clipboard | wl-clipboard |
| Fonts | JetBrainsMono Nerd Font, Noto |

---

## The Acer bootloader problem (read this if you have an Aspire E5)

This took four attempts to solve and is the single most likely thing to stop you.

Acer's InsydeH20 firmware **deletes UEFI boot entries it does not recognise**, silently,
on reboot. It also ignores the `\EFI\BOOT\BOOTX64.EFI` removable-media fallback.

What did **not** work:

1. `bootctl install` from inside `arch-chroot` — it prints
   *"Not booted with EFI or running in a container, skipping EFI variable modifications"*
   and never registers anything with the firmware.
2. The `BOOTX64.EFI` fallback path, created automatically by `bootctl install`.
3. `efibootmgr --create` pointing at `\EFI\systemd\systemd-bootx64.efi`, run from the
   live USB with genuine firmware access. The entry was created correctly and appeared
   in `efibootmgr -v` — and was **gone after the next reboot**.
4. The BIOS option *Security → Select an UEFI file as trusted for executing*, which is
   only selectable when Secure Boot is enabled.

What **did** work: put systemd-boot where the firmware already expects to find Windows.

```bash
mkdir -p /mnt/boot/EFI/Microsoft/Boot
cp /mnt/boot/EFI/systemd/systemd-bootx64.efi \
   /mnt/boot/EFI/Microsoft/Boot/bootmgfw.efi

efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "Windows Boot Manager" \
  --loader '\EFI\Microsoft\Boot\bootmgfw.efi' --unicode
```

The firmware has a hardcoded search for `\EFI\Microsoft\Boot\bootmgfw.efi`. It does not
verify that the file is actually Windows — it just runs it. The label is set to
"Windows Boot Manager" because some Acer firmware matches on the label as well as
the path. Full detail in [`docs/04-bootloader.md`](docs/04-bootloader.md).

---

## Deploying these dotfiles

Configs live in this repo and are symlinked into `~/.config` with GNU Stow. That means
editing a config edits the repo copy, `git diff` shows exactly what changed, and a bad
change is one `git checkout` away from being undone.

```bash
sudo pacman -S stow
git clone git@github.com:aivora017/nightcity.git ~/nightcity
cd ~/nightcity
stow hypr waybar kitty
```

Reinstall every package from the recorded list:

```bash
sudo pacman -S --needed - < docs/packages.txt
```

Regenerate that list after installing anything new:

```bash
pacman -Qqe > docs/packages.txt
```

---

## Documentation index

| File | Covers |
|---|---|
| [`docs/00-prerequisites.md`](docs/00-prerequisites.md) | Backups, ISO download and verification, bootable USB, BIOS settings |
| [`docs/01-live-environment.md`](docs/01-live-environment.md) | Booting the installer, console font, UEFI check, Wi-Fi, clock |
| [`docs/02-partitioning.md`](docs/02-partitioning.md) | Identifying drives, wiping, GPT partitions, formatting, Btrfs subvolumes, mounting |
| [`docs/03-base-install.md`](docs/03-base-install.md) | Mirrors, pacstrap, fstab, chroot, locale, users, sudo |
| [`docs/04-bootloader.md`](docs/04-bootloader.md) | systemd-boot, loader entries, and the full Acer firmware saga |
| [`docs/05-post-install.md`](docs/05-post-install.md) | zram, audio, graphics, Bluetooth, TLP, paru, Snapper |
| [`docs/06-desktop.md`](docs/06-desktop.md) | Hyprland, Kitty, Waybar, Wofi, fonts, first-run config |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Every problem hit during this build, with the fix |
| [`docs/LESSONS.md`](docs/LESSONS.md) | Habits that would have saved hours |
| [`docs/packages.txt`](docs/packages.txt) | Explicitly installed packages |

---

## Status

- [x] Base Arch install on Btrfs with subvolumes
- [x] Boots reliably past Acer firmware
- [x] Snapper snapshots with automatic pre/post package hooks
- [x] zram, audio, graphics, Bluetooth, power management
- [x] Hyprland running with Kitty and Firefox
- [x] Touchpad working
- [ ] Waybar themed
- [ ] Cyberpunk colour scheme applied
- [ ] Wallpaper and animations
- [ ] Eww widgets
- [ ] Lock screen

---

## Credit where it is due

Built following the [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
and a great deal of the [Arch Wiki](https://wiki.archlinux.org/) besides. The wiki is
the single best piece of documentation in Linux; when this repo and the wiki disagree,
believe the wiki.
