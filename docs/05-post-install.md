# 05 — Post-install essentials

You are logged in at `nightcity login:`. The system boots on its own. Now make it usable.

---

## 0. First login

### The zsh new-user wizard

On first login zsh shows a configuration wizard because you have no `.zshrc`. Press **`q`**
to quit without creating anything — a proper `.zshrc` comes later as part of the dotfiles,
and letting zsh generate its own just gets in the way.

It reappears every login until the file exists, so create an empty one now:

```bash
touch ~/.zshrc
```

### Get online

```bash
nmtui
```

A text menu: *Activate a connection* → pick your network → enter the password → `Esc` back
out. Arrow keys navigate, Enter selects.

```bash
ping -c 3 archlinux.org
sudo pacman -Syu
```

`-Syu` syncs the package database and upgrades everything. Your user password is what sudo
asks for.

---

## 1. zram — compressed swap in RAM

**What swap is:** RAM holds everything actively in use — open programs, browser tabs, the
desktop. It is fast but small. Swap is overflow space for when RAM fills up: Linux writes
the least recently used pages out to storage, freeing RAM for what you are using now.

Without swap, a full RAM triggers the **OOM killer** ("out of memory"), which force-kills a
program to save the system. It usually picks your browser, and you lose whatever you were
doing with no warning. On 4 GB you *will* hit this.

**What zram does:** creates a compressed block of swap **inside RAM itself**. Compressing
costs a little CPU, but the CPU is idle while waiting on disk anyway, so it is a good
trade. With zstd, typical data compresses around 3:1. A 4 GB machine behaves like it has
meaningfully more, and stays fast because nothing touches the disk.

```bash
sudo pacman -S zram-generator
sudo nano /etc/systemd/zram-generator.conf
```

```ini
[zram0]
zram-size = ram * 2
compression-algorithm = zstd
swap-priority = 100
```

`ram * 2` creates roughly 8 GB of compressed swap. It does not consume 8 GB of RAM — the
kernel only allocates what is actually in use, and stored pages are compressed.
`swap-priority = 100` is high, so zram is always preferred over any disk swap added later.

```bash
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service
swapon --show
free -h
```

Expected:

```
              total   used   free   shared  buff/cache   available
Mem:           3.7Gi  741Mi  1.8Gi     1.3Mi       1.5Gi       3.0Gi
Swap:          7.4Gi     0B  7.4Gi
```

That 741 MB is the entire system at the text console. Worth remembering as a baseline.

---

## 2. Audio

```bash
sudo pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
```

**PipeWire** is the modern audio server, replacing PulseAudio and JACK. **WirePlumber** is
its session manager, deciding which application gets which device.

These start automatically per-user — no `systemctl enable` needed.

---

## 3. Intel graphics

```bash
sudo pacman -S mesa vulkan-intel intel-media-driver libva-intel-driver
```

| Package | Purpose |
|---|---|
| `mesa` | Open-source graphics stack, provides OpenGL |
| `vulkan-intel` | Vulkan support, which Hyprland can use |
| `intel-media-driver` | Hardware video decoding on HD 620 — the GPU decodes video instead of the CPU, which matters a lot for battery life and smooth playback on 4 GB |
| `libva-intel-driver` | Older VA-API driver, kept for app compatibility |

**No NVIDIA drivers are installed.** The 940MX is Maxwell-generation and current NVIDIA
drivers have dropped that generation. NVIDIA plus Wayland on old hybrid laptops is a
classic source of pain, and the Intel iGPU handles Hyprland's blur and animations fine.

---

## 4. Bluetooth

```bash
sudo pacman -S bluez bluez-utils
sudo systemctl enable --now bluetooth
```

`--now` both enables it for future boots and starts it immediately.

---

## 5. Power management

```bash
sudo pacman -S tlp
sudo systemctl enable --now tlp
```

**TLP** applies laptop power-saving defaults automatically: CPU frequency scaling, disk
spindown for the HDD, USB autosuspend, Wi-Fi power saving, battery charge thresholds. On
this hardware it makes a real difference with no configuration needed.

Verify:

```bash
systemctl status tlp bluetooth --no-pager
```

Both should be `active`. TLP shows `active (exited)` — correct, since it is a one-shot
service that applies settings and finishes.

---

## 6. paru — the AUR helper

The **AUR** (Arch User Repository) is a community collection of build recipes for software
not in the official repos. Hyprland plugins, themes, and many rice tools live there.

> ### Do not use `paru-bin`
>
> The obvious approach is `paru-bin`, which installs instantly because it is precompiled.
> On this system it failed immediately:
>
> ```
> paru: error while loading shared libraries: libalpm.so.15:
>       cannot open shared object file: No such file or directory
> ```
>
> ```bash
> ls /usr/lib/libalpm.so*
> /usr/lib/libalpm.so  /usr/lib/libalpm.so.16  /usr/lib/libalpm.so.16.0.1
> ```
>
> The binary was built against pacman's library version **15**; this system has **16**.
> This is the general hazard of `-bin` packages: they install instantly but break whenever
> the library they were linked against changes. On a rolling-release distro, source
> packages are the safer default for anything linking against system libraries.

Remove the broken one if you installed it:

```bash
sudo pacman -Rns paru-bin paru-bin-debug
```

`-Rns` removes the package plus unneeded dependencies and its config files.

Build from source instead:

```bash
cd ~
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

| Flag | Meaning |
|---|---|
| `makepkg` | Reads the PKGBUILD recipe and builds a package |
| `-s` | Install missing build dependencies |
| `-i` | Install the finished package |

When asked which Rust provider to use, choose **`1) rust`** — the standard Arch package,
managed by pacman. `rustup` is a version manager for people needing multiple toolchains.

This compiles Rust. Expect **15–30 minutes** on an i5-7200U. If the build gets killed for
memory, limit parallelism:

```bash
MAKEFLAGS="-j2" makepkg -si
```

Clean up and verify:

```bash
cd ~
rm -rf paru
paru --version
```

```
paru v2.1.0 - libalpm v16.0.1
```

Note it now reports the *matching* libalpm version.

> If you get `command not found: paru` immediately after installing, run **`rehash`**.
> Zsh caches which binaries exist in your PATH and does not notice new ones until told.

> **On AUR safety:** these are user-submitted build scripts, not vetted by Arch. Read the
> PKGBUILD before installing anything obscure. `paru` shows you the diff by default — do
> not just press Enter through it.

---

## 7. Snapper — snapshots and rollback

```bash
sudo pacman -S snapper snap-pac
```

**`snap-pac`** is the piece that makes this genuinely useful: it hooks into pacman so a
snapshot is taken automatically *before and after every package operation*. If an update
breaks something, the pre-update state is already saved.

### The subvolume dance

Snapper insists on creating its own `/.snapshots` subvolume, but we already created one in
[chapter 02](02-partitioning.md) and it is mounted. So:

```bash
sudo umount /.snapshots
sudo rm -rf /.snapshots

sudo snapper -c root create-config /

sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
```

Step by step: unmount ours, remove the empty directory, let Snapper create its config
(which makes *its* `/.snapshots` subvolume), delete that, recreate the mount point, and
`mount -a` remounts everything in fstab — which reattaches our original `@snapshots`.

**Verify before continuing:**

```bash
findmnt /.snapshots
```

```
TARGET      SOURCE                      FSTYPE OPTIONS
/.snapshots /dev/nvme0n1p2[/@snapshots] btrfs  rw,noatime,compress=zstd:3,...
```

The `[/@snapshots]` is what you are checking for.

### Configure limits

```bash
sudo nano /etc/snapper/configs/root
```

```ini
ALLOW_USERS="sourav"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
```

`ALLOW_USERS` lets you manage snapshots without sudo. The defaults keep far more snapshots
than needed — on a 465 GB drive that is survivable, but there is no point holding a year of
them.

```bash
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
```

### Create your first restore point

```bash
sudo snapper -c root create --description "base system installed"
sudo snapper -c root list
```

```
 # | Type   | Pre # | Date                            | User | Description
---+--------+-------+---------------------------------+------+-----------------------
 0 | single |       |                                 | root | current
 1 | single |       | Sun 13 Sep 2026 12:57:59 AM IST | root | base system installed
```

From here on, every `pacman -S` produces pre and post snapshots automatically. You will see
this in pacman output:

```
(4/4) Performing snapper post snapshots for the following configurations...
==> root: 9
```

---

## 8. Useful extras

```bash
sudo pacman -S reflector openssh wl-clipboard
```

| Package | Why |
|---|---|
| `reflector` | Exists in the live environment but **not** in a fresh install. You will want it when mirrors go slow |
| `openssh` | Provides `ssh-keygen` and `ssh`, needed to push to GitHub |
| `wl-clipboard` | Wayland clipboard tools — `wl-copy` and `wl-paste` |

---

## Checkpoint

```bash
free -h                                    # Swap shows ~7.4 GB
systemctl status tlp bluetooth --no-pager  # both active
findmnt /.snapshots                        # subvol=/@snapshots
paru --version                             # matching libalpm version
sudo snapper -c root list                  # at least one snapshot
```

Continue to [`06-desktop.md`](06-desktop.md).
