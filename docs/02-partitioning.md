# 02 — Partitioning and filesystems

This is the destructive step. Everything on both drives is about to be erased.

---

## Concepts first

### EFI System Partition (ESP)

When you press power, the firmware runs before any OS. It has to find and start
something, but it does not understand Linux or Btrfs. It knows how to read exactly one
thing: **a FAT32 partition flagged as an EFI System Partition**.

So the ESP is a landing pad. It holds `.efi` files — bootloaders. The firmware reads that
partition, finds the bootloader, and hands over control. The bootloader then loads the
Linux kernel.

FAT32 is ancient and limited, but every UEFI firmware on earth can read it. We give it
**1 GB** rather than the ~100 MB Windows uses, because Linux stores kernel images and
initramfs files there — roughly 100 MB per kernel — and having room for several versions
plus a fallback avoids a full-ESP headache during an update.

### ext4

The long-standing default Linux filesystem. A **filesystem** is the scheme that turns raw
bytes on a drive into files and folders, tracking each file's location, name, size and
permissions.

ext4 has been the standard since 2008. It is fast, extremely well tested, and it just
works. It uses **journaling**: before writing, it records what it is about to do, so a
power loss mid-write is replayed cleanly on the next boot instead of leaving corruption.

What it does not do: snapshots, built-in compression, or checksums on file data. For the
HDD — movies, wallpapers, backups — none of that matters. ext4 is the right tool there.

### Btrfs

The "B-tree filesystem", pronounced butter-FS. Newer, much more capable, and the reason
the rollback plan works.

**Copy-on-write** is the core idea. When you modify a file, ext4 overwrites the old data
in place. Btrfs writes the change to a *new* location and updates the pointer. The old
data sits untouched until nothing references it any more.

That property gives **snapshots for free**. A snapshot is a record saying "keep everything
as it was at this moment". It is instant even on a 400 GB filesystem, and initially takes
almost no space because it is only pointers to blocks that already exist. Space is
consumed gradually as files change and old versions must be kept.

**Subvolumes** act like independent filesystems that share one pool of free space. No more
"root is full while home has 200 GB free". And you can snapshot them separately — rolling
back a broken system update should not undo the documents you wrote this morning.

**Compression** with zstd is transparent. Text, code and configs shrink a lot; already
compressed files like video are detected and skipped. It can even be *faster*, since
reading less data from disk outweighs the CPU cost of decompressing.

---

## 1. Identify the drives

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
```

Real output from this machine:

```
NAME      SIZE TYPE MODEL
loop0   1018.8M loop
sda     931.5G disk TOSHIBA MQ01ABD100
├─sda1    512M part
└─sda2     931G part
sdb      14.9G disk Cruzer Blade          <- the USB installer
├─sdb1     1.2G part
└─sdb2     260M part
sr0      1024M rom  Slimtype DVD A DA8AESH
nvme0n1 465.8G disk KINGSTON SNV2S500G
├─nvme0n1p1  450M part
├─nvme0n1p2  100M part
├─nvme0n1p3   16M part
├─nvme0n1p4 464.7G part
└─nvme0n1p5  516M part
```

Reading it:

- Lines with `TYPE = disk` are whole drives; `part` lines are partitions, shown indented
- A **500 GB** SSD shows as **465 GB**, and a **1 TB** HDD as **931 GB**. Manufacturers
  count 1 GB as 1,000,000,000 bytes; the OS counts 1,073,741,824. Nothing is missing
- The five partitions on `nvme0n1` are a textbook Windows UEFI layout: recovery, ESP,
  MSR, C:, recovery
- `sr0` at `1024M rom` is the **empty DVD drive**. That size is a placeholder the kernel
  reports when no disc is inserted. Ignore it entirely

### Confirm which is SSD and which is HDD

```bash
lsblk -d -o NAME,SIZE,ROTA,MODEL
```

`ROTA` means rotational. **`1` = spinning HDD**, **`0` = SSD**. `-d` shows only whole
drives.

### NVMe naming

NVMe drives use a different scheme: partitions get a `p`, so `nvme0n1p1`, not `nvme0n11`.
SATA drives are `sda1`, `sda2` and so on.

> **Write down which device is which before continuing.** Every command below names a
> device explicitly. If you ever find yourself typing the USB's name, stop.

For this build:

| Device | What it is | Fate |
|---|---|---|
| `nvme0n1` | Kingston 500 GB SSD | wiped and repartitioned |
| `sda` | Toshiba 1 TB HDD | wiped and repartitioned |
| `sdb` | SanDisk Cruzer Blade USB | **do not touch** |
| `sr0` | Empty DVD drive | ignore |

---

## 2. Wipe

```bash
wipefs -a /dev/nvme0n1
wipefs -a /dev/sda
```

`wipefs` erases the magic bytes that identify a filesystem or partition table. `-a` means
all of them. This is what makes the drive look genuinely blank rather than leaving Windows
remnants that confuse later tools.

Expect output listing each signature removed, ending in
`calling ioctl to re-read partition table: Success`.

```bash
sgdisk --zap-all /dev/nvme0n1
sgdisk --zap-all /dev/sda
```

`sgdisk` manages GPT partition tables. `--zap-all` destroys the GPT *and* any legacy MBR,
**including the backup GPT copy stored at the end of the drive**. Without this, leftover
partition entries can reappear.

Expect: `GPT data structures destroyed!`

---

## 3. Create partitions

### SSD

```bash
sgdisk --new=1:0:+1G --typecode=1:ef00 --change-name=1:"EFI" /dev/nvme0n1
sgdisk --new=2:0:0   --typecode=2:8300 --change-name=2:"ROOT" /dev/nvme0n1
```

| Argument | Meaning |
|---|---|
| `--new=1:0:+1G` | Create partition 1; `0` = start at first available sector; `+1G` = make it 1 GB |
| `--new=2:0:0` | Create partition 2; second `0` = use all remaining space |
| `--typecode=1:ef00` | Tag as EFI System Partition. `ef00` is what tells the firmware to look here |
| `--typecode=2:8300` | Generic Linux filesystem |
| `--change-name` | A human-readable label stored in the GPT |

### HDD

```bash
sgdisk --new=1:0:0 --typecode=1:8300 --change-name=1:"DATA" /dev/sda
```

### Verify

```bash
lsblk -o NAME,SIZE,TYPE,PARTLABEL
```

```
sda          931.5G disk
└─sda1       931.5G part DATA
nvme0n1      465.8G disk
├─nvme0n1p1      1G part EFI
└─nvme0n1p2  464.8G part ROOT
```

Five Windows partitions replaced by two. Good.

> **If a `sgdisk` command produced no output at all**, it failed before touching the disk.
> `sgdisk` parses every option before writing, so a mistyped flag (`--chnage-name`) means
> nothing happened rather than something happening wrongly. Fix the spelling and rerun.

---

## 4. Format

```bash
mkfs.fat -F32 -n EFI /dev/nvme0n1p1
mkfs.btrfs -L ROOT /dev/nvme0n1p2
mkfs.ext4 -L DATA /dev/sda1
```

| Flag | Meaning |
|---|---|
| `-F32` | **Required.** Forces FAT32 rather than FAT16. Without it, `mkfs.fat` picks based on size and a 1 GB partition may become FAT16, which UEFI can refuse to boot from |
| `-n` / `-L` | Sets the filesystem label (distinct from the GPT partition label set earlier) |

`mkfs.ext4` takes a while — it writes inode tables across the whole 931 GB.

> **Formatting is idempotent.** Running `mkfs` again just produces the same clean result.
> If you are unsure whether a format did what you wanted, redoing it costs nothing as long
> as you have not written data yet. The same is true of `mkfs.btrfs` and `mkfs.ext4`.
>
> The commands where a mistake actually matters are `dd` to the wrong device, `rm -rf` on
> real data, and later `arch-chroot` operations on a system you have already built.

---

## 5. Create Btrfs subvolumes

Mount the Btrfs filesystem temporarily so you can create subvolumes inside it:

```bash
mount /dev/nvme0n1p2 /mnt
```

```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
```

They look like directories but are independently snapshottable units. The `@` prefix is a
widely used convention rather than a requirement — Snapper and other tooling expect it.

Check:

```bash
btrfs subvolume list /mnt
```

```
ID 256 gen 10 top level 5 path @
ID 257 gen 10 top level 5 path @home
ID 258 gen 10 top level 5 path @snapshots
ID 259 gen 10 top level 5 path @log
ID 260 gen 11 top level 5 path @pkg
```

Unmount, because each subvolume now gets mounted in its proper place:

```bash
umount /mnt
```

> Note the spelling: **`umount`**, no "n" after the u.

---

## 6. Mount everything

Set the options once:

```bash
export BTRFS_OPTS="noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"
```

| Option | What it does |
|---|---|
| `noatime` | Stops Linux writing an "accessed at" timestamp every time a file is *read*. That is a write for every read — pointless overhead and extra SSD wear |
| `compress=zstd:3` | Transparent zstd compression. Levels run 1–15; 3 is the sweet spot for speed vs ratio. Already-compressed files are detected and skipped |
| `ssd` | Use allocation patterns suited to solid-state drives |
| `discard=async` | Enables TRIM so the SSD knows which blocks are free and can manage wear. `async` batches it in the background instead of stalling on every delete |
| `space_cache=v2` | Modern free-space tracking; much faster on large filesystems |

Mount the root subvolume:

```bash
mount -o $BTRFS_OPTS,subvol=@ /dev/nvme0n1p2 /mnt
```

`subvol=@` says "mount this specific subvolume as the root of this mount point".

Create the directories the other subvolumes attach to:

```bash
mkdir -p /mnt/{home,.snapshots,var/log,var/cache/pacman/pkg,boot,data}
```

`-p` creates parent directories as needed. The `{...}` is brace expansion — a shell
shortcut turning one command into six.

Mount the rest:

```bash
mount -o $BTRFS_OPTS,subvol=@home      /dev/nvme0n1p2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/nvme0n1p2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@log       /dev/nvme0n1p2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@pkg       /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/sda1 /mnt/data
```

No special options on `/boot` — FAT32 does not support them.

---

## 7. Verify the mount tree

```bash
findmnt -R /mnt
```

`-R` shows the result as a tree. You want seven entries:

```
TARGET                      SOURCE                       FSTYPE OPTIONS
/mnt                        /dev/nvme0n1p2[/@]           btrfs  rw,noatime,compress=zstd:3,...,subvol=/@
├─/mnt/home                 /dev/nvme0n1p2[/@home]       btrfs  ...,subvol=/@home
├─/mnt/.snapshots           /dev/nvme0n1p2[/@snapshots]  btrfs  ...,subvol=/@snapshots
├─/mnt/var/log              /dev/nvme0n1p2[/@log]        btrfs  ...,subvol=/@log
├─/mnt/var/cache/pacman/pkg /dev/nvme0n1p2[/@pkg]        btrfs  ...,subvol=/@pkg
├─/mnt/boot                 /dev/nvme0n1p1               vfat   rw,relatime,fmask=0022,...
└─/mnt/data                 /dev/sda1                    ext4   rw,relatime
```

**Check each Btrfs line shows a different `subvol=`.** A subvolume mounted at the wrong
path means the install goes into the wrong place, and you will not find out until much
later.

Continue to [`03-base-install.md`](03-base-install.md).

---

## A note on swap

There is deliberately no swap partition here. The options were:

| Option | Trade-off |
|---|---|
| **Swap partition** | Traditional, reliable. Size is fixed at install time; resizing means repartitioning |
| **Swap file** | Just as fast on modern kernels, and can be created, resized or deleted any time with a few commands |
| **zram** | Compressed swap *inside RAM*. No disk I/O, no SSD wear, roughly 3:1 compression with zstd |

**zram was chosen.** On 4 GB of RAM this is exactly the case it was designed for, and both
Fedora and Ubuntu now enable it by default. Swapping to the spinning HDD would be
genuinely slow; swapping to the SSD works but burns write cycles.

The only thing given up is **hibernation** (suspend-to-disk), which needs real disk swap at
least as large as RAM and cannot use zram — zram disappears when the power does. Ordinary
sleep still works and resumes in a second or two.

Not creating a swap partition costs nothing, because a swap file can be added at any time.
Creating one and regretting it means repartitioning. See
[`05-post-install.md`](05-post-install.md) for the zram setup.
