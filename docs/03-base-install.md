# 03 — Base system install

Filesystems are mounted at `/mnt`. Now Arch actually gets written to the SSD.

---

## 1. Optimise the mirror list

Arch downloads packages from **mirrors** — servers around the world hosting copies of the
repositories. The installer ships with a default list which may be slow from your region.

```bash
reflector --country India,Singapore --protocol https --sort rate --latest 20 \
  --save /etc/pacman.d/mirrorlist
```

| Flag | Meaning |
|---|---|
| `--country` | Limit to nearby servers |
| `--protocol https` | Encrypted transfers only |
| `--sort rate` | Rank by measured download speed, not just ping |
| `--latest 20` | Consider only the 20 most recently synced mirrors, avoiding stale ones |
| `--save` | Write the result to the file pacman reads |

This takes a minute or two while it speed-tests. Warnings like
`failed to rate http(s) download ... Download timed out after 5 second(s)` are **normal** —
reflector is discarding mirrors that are too slow. That is the job.

### Verify it worked

```bash
grep -c "^Server" /etc/pacman.d/mirrorlist
```

You want **at least 5**. Note the capital `S` — `grep -c "^server"` returns `0` because
the file uses `Server`, which looks alarming but means nothing.

```bash
grep "^Server" /etc/pacman.d/mirrorlist
```

Indian mirrors are identifiable by airport codes: `bom` = Mumbai, `maa` = Chennai.

> **Watch the `--save` path carefully.** A typo here (`mirroelist` instead of
> `mirrorlist`) silently creates a brand-new file at the wrong path and leaves the real
> mirror list untouched. Nothing errors. Use Tab completion: type
> `/etc/pacman.d/mirr` then press Tab.

---

## 2. Enable parallel downloads

```bash
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
```

`sed` edits text in place; this uncomments the line so pacman fetches five packages at
once instead of one at a time.

```bash
grep ParallelDownloads /etc/pacman.conf
```

You want `ParallelDownloads = 5` with no `#`.

---

## 3. Install the base system

`pacstrap` installs packages into a target directory rather than the running system.

```bash
pacstrap -K /mnt base base-devel linux linux-lts linux-firmware intel-ucode \
  btrfs-progs networkmanager nano vim git sudo man-db man-pages texinfo zsh efibootmgr
```

`-K` initialises a fresh pacman keyring in the new system for verifying package signatures.

| Package | Why |
|---|---|
| `base` | The minimal set that defines an Arch system |
| `base-devel` | Compilers and build tools — **required** for AUR packages later |
| `linux` | Current kernel; needed for good Hyprland and Intel graphics support |
| `linux-lts` | Long-term-support kernel as a **fallback**. If a kernel update breaks booting, pick LTS at the boot menu |
| `linux-firmware` | Binary firmware blobs for Wi-Fi, graphics, Bluetooth |
| `intel-ucode` | CPU microcode updates for the i5-7200U — security and stability fixes applied at boot |
| `btrfs-progs` | **Essential.** Without it the system cannot mount its own root filesystem |
| `networkmanager` | Manages Wi-Fi in the installed system; `iwctl` only exists in the live environment |
| `nano`, `vim` | Text editors |
| `git` | For the dotfiles repo |
| `sudo` | Run commands as administrator from a normal user |
| `man-db`, `man-pages`, `texinfo` | Offline documentation, so `man btrfs` works |
| `zsh` | The shell configured later |
| `efibootmgr` | Manages UEFI boot entries — needed heavily on Acer |

Expect several hundred MB and 10–25 minutes. It finishes with mkinitcpio building an
initramfs for each kernel:

```
==> Creating zstd-compressed initcpio image: '/boot/initramfs-linux.img'
==> Initcpio image generation successful
```

A warning that `/etc/vconsole.conf` was not found is expected — that file is created later.

### Verify nothing was dropped

```bash
arch-chroot /mnt pacman -Q btrfs-progs networkmanager sudo git efibootmgr zsh
```

---

## 4. Generate fstab

**fstab** tells the system what to mount at boot. Right now the mounts exist only in the
live environment's memory.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

| Part | Meaning |
|---|---|
| `-U` | Use **UUIDs** instead of device names. Device names like `sda` can shift if a USB drive is plugged in at boot; a UUID always identifies the same filesystem |
| `>>` | **Append.** A single `>` overwrites |

> **Run this exactly once.** Running it twice with `>>` produces duplicate entries, which
> causes boot failures. If that happens, edit `/mnt/etc/fstab` and delete the extras.

```bash
cat /mnt/etc/fstab
```

Seven entries, all starting with `UUID=`, five distinct `subvol=` values. The `/data` line
ends in `0 2` (ext4 gets an fsck pass at boot); the Btrfs lines end in `0 0`, which is
correct — Btrfs does not use fsck that way.

---

## 5. Enter the new system

```bash
arch-chroot /mnt
```

**chroot** means "change root". It makes `/mnt` appear as `/`, so from here on you are
operating inside the installed system. The prompt becomes `[root@archiso /]#`.

---

## 6. Timezone

```bash
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
```

`ln -s` creates a symbolic link (a pointer to another file); `-f` overwrites any existing
one. `/etc/localtime` is where the system looks for the current timezone.

```bash
hwclock --systohc
```

Writes the current system time to the hardware clock **in UTC**. The hardware stores UTC
and the timezone link converts it for display — which is why the live environment showed
UTC earlier.

```bash
date
```

Should now show IST.

---

## 7. Locale

A **locale** defines language, character encoding, and formatting for dates, numbers and
currency.

```bash
nano /etc/locale.gen
```

Find and uncomment (delete the leading `#`):

```
en_US.UTF-8 UTF-8
en_IN UTF-8
```

In nano, `Ctrl+W` searches — type `en_US.UTF-8` and press Enter to jump straight there.
Save with `Ctrl+O`, Enter, exit with `Ctrl+X`.

```bash
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

`en_US.UTF-8` is recommended as the system default over `en_IN` — it is the best-supported
locale and avoids occasional missing-translation quirks. You still get IST from the
timezone setting.

---

## 8. Console keymap

```bash
echo "KEYMAP=us" > /etc/vconsole.conf
```

This creates the file mkinitcpio warned about. `us` is correct for a standard Indian
laptop keyboard, which uses the US QWERTY physical layout.

---

## 9. Hostname

```bash
echo "nightcity" > /etc/hostname
```

Lowercase, no spaces. Then the hosts file:

```bash
nano /etc/hosts
```

```
127.0.0.1   localhost
::1         localhost
127.0.1.1   nightcity.localdomain   nightcity
```

| Address | Meaning |
|---|---|
| `127.0.0.1` | IPv4 loopback — "this machine" |
| `::1` | IPv6 equivalent |
| `127.0.1.1` | Maps your hostname to loopback; some applications need to resolve their own machine name |

Replace `nightcity` with your hostname in both places on the last line.

---

## 10. Root password

```bash
passwd
```

> **Nothing appears as you type** — not even asterisks. That is normal Unix behaviour, not
> a frozen terminal.

If you lose the root password you will need the USB to recover.

---

## 11. Create your user

Running as root all the time is dangerous: a typo can destroy the system with no
confirmation.

```bash
useradd -m -G wheel -s /bin/zsh sourav
passwd sourav
```

| Flag | Meaning |
|---|---|
| `-m` | Create the home directory at `/home/sourav` |
| `-G wheel` | Add to the **wheel** group — by convention, the group allowed to use sudo |
| `-s /bin/zsh` | Set zsh as the login shell |

Verify:

```bash
id sourav
```

```
uid=1000(sourav) gid=1000(sourav) groups=1000(sourav),998(wheel)
```

---

## 12. Enable sudo for wheel

```bash
EDITOR=nano visudo
```

> **Use `visudo`, never edit `/etc/sudoers` directly.** visudo checks syntax before
> saving. A broken sudoers file locks you out of sudo entirely — and since you would need
> sudo to fix it, that means booting the USB again.

Find this line roughly two-thirds down and delete the `# `:

```
# %wheel ALL=(ALL:ALL) ALL
```

becomes

```
%wheel ALL=(ALL:ALL) ALL
```

> **Do not uncomment the `NOPASSWD` variant a few lines below.** That would let anyone in
> the wheel group run any command as root without a password.

Save with `Ctrl+O`, Enter, `Ctrl+X`. If visudo reports a syntax error it will offer to
re-edit — take that option rather than saving anyway.

---

## 13. Enable NetworkManager

```bash
systemctl enable NetworkManager
```

**Capital N, capital M** — systemd unit names are case-sensitive.

`systemctl enable` marks a service to start automatically at boot. Without this, the
installed system boots with no network at all, and no browser to look up how to fix it.

Expect three "Created symlink" lines.

---

## Checkpoint

```bash
cat /boot/loader/loader.conf   # (does not exist yet — next chapter)
id sourav                      # shows wheel
cat /etc/fstab                 # seven UUID entries
date                           # shows IST
```

Continue to [`04-bootloader.md`](04-bootloader.md).
