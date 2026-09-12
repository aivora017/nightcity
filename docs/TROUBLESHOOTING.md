# Troubleshooting

Every problem hit during this build, with the symptom, the cause, and the fix.

**Jump to:**
[Boot](#boot) ·
[Firmware](#firmware) ·
[Packages and mirrors](#packages-and-mirrors) ·
[Hardware](#hardware) ·
[Configs and shell](#configs-and-shell) ·
[Git and SSH](#git-and-ssh)

---

## Boot

### "No Bootable Device"

**Symptom:** padlock-free grey screen with a magnifying-glass icon after removing the USB.

**Cause:** the firmware has no registered UEFI entry pointing at your bootloader. If you
ran `bootctl install` inside `arch-chroot`, it printed
*"Not booted with EFI or running in a container, skipping EFI variable modifications"* and
never told the firmware anything.

**Fix:** see the full saga in [`04-bootloader.md`](04-bootloader.md#6-the-acer-firmware-saga).
Short version — put systemd-boot at the Microsoft path:

```bash
# from the live USB
mount -o subvol=@ /dev/nvme0n1p2 /mnt
mount /dev/nvme0n1p1 /mnt/boot
mkdir -p /mnt/boot/EFI/Microsoft/Boot
cp /mnt/boot/EFI/systemd/systemd-bootx64.efi /mnt/boot/EFI/Microsoft/Boot/bootmgfw.efi
efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "Windows Boot Manager" \
  --loader '\EFI\Microsoft\Boot\bootmgfw.efi' --unicode
umount -R /mnt
reboot
```

---

### A boot entry created with `efibootmgr` vanishes after reboot

**Symptom:** `efibootmgr -v` shows your entry perfectly. After a reboot it is gone, and the
next entry you create reuses the same `Boot000X` number.

**Cause:** Acer InsydeH20 firmware silently purges UEFI entries it does not recognise.

**Fix:** use a path the firmware auto-detects — `\EFI\Microsoft\Boot\bootmgfw.efi`. It
regenerates that entry itself rather than deleting it.

---

### Boot menu does not appear, goes straight to login

Not a problem. `timeout 3` elapsed without a keypress. Press a key during those three
seconds to see the menu.

---

### `umount: /mnt: target is busy`

Something still has a directory under `/mnt` open, usually your own shell.

```bash
cd /
umount -R /mnt
```

Note the **dash**: `umount -R`, not `umount R`. Without it, `R` is treated as a mount point
name and you get `umount: R: no mount point specified`.

---

## Firmware

### "Security Boot Fail" padlock screen

**Symptom:** a white padlock with a red exclamation mark, after a full power-off on a
system that was booting fine.

**Cause:** Acer firmware re-enabled Secure Boot on its own.

**Fix:** `F2` → **Boot** tab → **Secure Boot** → `Disabled` → `F10` to save and exit.

**If Secure Boot is greyed out:** go to the **Security** tab and confirm
*Supervisor Password Is: Set*. If it says Clear, set one, save with `F10`, re-enter BIOS,
then disable Secure Boot.

**If it recurs on every power-off:** suspect a weak CMOS battery, or enrol your own keys
with [`sbctl`](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#sbctl)
so Secure Boot can stay enabled and still boot your system.

---

### "Select an UEFI file as trusted for executing" is greyed out

It lives inside a Secure Boot submenu and only becomes selectable with Secure Boot
**enabled** — which defeats the purpose for an unsigned bootloader. Use the
`efibootmgr` + Microsoft-path approach instead.

---

## Packages and mirrors

### A mirror stalls mid-download

**Symptom:**

```
error: failed retrieving file 'xyz.pkg.tar.zst.sig' from sg.mirrors.cicku.me :
       Operation too slow. Less than 1 bytes/sec transferred the last 10 seconds
warning: failed to retrieve some files
error: failed to commit transaction (failed to retrieve some files)
```

**Nothing was installed and nothing is broken.** Packages already downloaded stay cached in
`/var/cache/pacman/pkg`, so a retry resumes rather than starting over — watch the
"Total Download Size" drop between attempts.

**Fix 1 — disable the specific bad mirror:**

```bash
sudo sed -i '/cicku/s/^/#/' /etc/pacman.d/mirrorlist
grep -c "^Server" /etc/pacman.d/mirrorlist   # make sure ≥5 remain
```

**Fix 2 — refresh the whole list:**

```bash
sudo reflector --country India,Japan,Germany --protocol https --sort rate --latest 15 \
  --save /etc/pacman.d/mirrorlist
```

Then simply rerun the install command.

> In this build one mirror served packages fine but consistently choked on tiny `.sig`
> signature files. Removing it entirely was the right call rather than hoping for better
> luck.

---

### `reflector: command not found` on the installed system

Reflector exists in the live environment but is **not** part of a base install.

```bash
sudo pacman -S reflector
```

If pacman itself cannot reach a mirror to install it, edit the list by hand:

```bash
sudo nano /etc/pacman.d/mirrorlist
```

Comment out the offending line with `#` and retry.

---

### `reflector` fails with a TLS handshake timeout

```
error: failed to retrieve mirrorstatus data: URLError:
       <urlopen error _ssl.c:1064: The handshake operation timed out>
```

This is **your** connection, not a mirror. Reflector could not reach archlinux.org at all.

```bash
ping -c 5 archlinux.org
```

Compare to a known-good result (~63 ms, 0% loss on this build). If you are on a Wi-Fi range
extender (`_EXT` in the SSID), switch to the main router — extenders roughly halve
throughput and add instability.

---

### `paru: error while loading shared libraries: libalpm.so.15`

**Cause:** `paru-bin` is precompiled against a specific pacman library version. Your system
has a different one.

```bash
ls /usr/lib/libalpm.so*
# /usr/lib/libalpm.so  /usr/lib/libalpm.so.16  /usr/lib/libalpm.so.16.0.1
```

**Fix:** build paru from source so it links against what you actually have.

```bash
sudo pacman -Rns paru-bin paru-bin-debug
cd ~
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si          # choose 1) rust when prompted
cd ~ && rm -rf paru
paru --version       # should report the matching libalpm version
```

Takes 15–30 minutes on an i5-7200U. If the compile gets killed for memory,
`MAKEFLAGS="-j2" makepkg -si`.

**General lesson:** on a rolling-release distro, `-bin` packages install instantly but
break whenever the library they were built against changes. Prefer source for anything
that links against system libraries.

---

### `command not found` immediately after installing a package

```bash
rehash
```

Zsh caches which binaries exist in your PATH and does not notice new ones until told. This
bit twice during the build — once with `libinput`, once with `paru`.

---

### `libinput: command not found` even though libinput is installed

The library and the command-line tool are separate packages:

```bash
sudo pacman -S libinput-tools
```

---

## Hardware

### ath10k AER errors flooding the console

**Symptom:** repeated lines making the terminal unusable:

```
ath10k_pci 0000:03:00.0: AER: Error of this Agent is reported first
```

**Cause:** PCIe Advanced Error Reporting logging *correctable* errors the hardware already
recovered from. Very common with `ath10k` cards on older laptops. Wi-Fi works fine.

**Immediate fix (this session only):**

```bash
sudo dmesg -n 1
```

Sets the console log level so only true emergencies print to screen. Messages still go to
the journal — nothing is lost.

**Permanent fix:** add `pci=noaer` to the end of the `options` line in **both**
`/boot/loader/entries/arch.conf` and `arch-lts.conf`. Takes effect on next boot.

---

### Touchpad detected but the cursor does not move

This one took a while, and the answer was surprising.

**Diagnosis sequence — work through it in order:**

```bash
# 1. Does the kernel see it?
sudo libinput list-devices | grep -A5 -i touchpad
```

```
Device:  ELAN0501:00 04F3:3019 Touchpad
Kernel:  /dev/input/event9
Id:      i2c:04f3:3019
Size:    101x73mm
```

```bash
# 2. Does the compositor see it?
hyprctl devices | grep -A15 -i mice
```

```
Mouse at 55f71deab080:
    elan0501:00-04f3:3019-touchpad
```

```bash
# 3. Is it sending events?
sudo libinput debug-events --device /dev/input/event9
```

Move your finger, then `Ctrl+C`.

**Interpreting step 3:**

| What you see | Meaning |
|---|---|
| `POINTER_MOTION` lines | Device is fine; the problem is config |
| Only `GESTURE_HOLD_BEGIN` / `GESTURE_HOLD_END` | Device reports finger **contact** but no **coordinates** |
| Nothing at all | Device is sending nothing — check the `Fn` toggle |

In this build the result was the middle one — contact but no position data.

**Things that did *not* fix it:**

- `libinput` / `libinput-tools` (already installed, or irrelevant)
- Adding the touchpad block to the Hyprland config
- `sudo modprobe hid_multitouch` — loaded, but usage count stayed `0`, meaning it bound to
  nothing
- `sudo dmesg | grep -i elan` returned **nothing at all**, as did
  `grep -i i2c_designware` — the kernel never logged initialising the device properly

**What fixed it: a full power-off.** Not a reboot — a complete shutdown with the power
removed, then a cold start.

> **I2C devices often are not fully reset by a warm reboot.** The touchpad was stuck in a
> bad state left behind by Windows. Cutting power entirely cleared it.
>
> Worth remembering generally: **for input or USB devices behaving strangely, try a full
> shutdown rather than a reboot.**

**Also check the hardware toggle.** On an Aspire E5-575G it is **`Fn + F7`** — the key with
a touchpad-and-slash icon. If a previous OS left it disabled, no amount of driver work will
help. Press it, test, press it again, test.

**Meanwhile, plug in a USB mouse.** It confirms the rest of the input stack is fine and
unblocks you immediately.

---

### Cursor renders but nothing responds, and two windows seem stacked

Input is going to whichever window has focus.

| Key | Action |
|---|---|
| `Super + J` / `Super + K` | Cycle focus |
| `Super + C` | Close focused window |
| `Super + M` | Exit Hyprland entirely (nothing is lost) |

---

## Configs and shell

### zsh new-user wizard appears on every terminal

```bash
touch ~/.zshrc
```

An empty file satisfies zsh. Press `q` to dismiss the current one.

---

### Hyprland config file is `.lua`, not `.conf`

Recent versions generate `~/.config/hypr/hyprland.lua`. The warning bar at the top of a
fresh Hyprland session states the exact path — read it rather than assuming.

The formats are **not** interchangeable. Lua needs `=` after block names, trailing commas,
and underscores instead of hyphens in identifiers (`tap_to_click`, not `tap-to-click`).

---

### "Your config has errors: unknown config key ..."

Hyprland validates on save and names the exact key and line number:

```
/home/sourav/.config/hypr/hyprland.lua:226: unknown config key 'input.touchpad.tap_to_clcik'
```

Read it. It contains the whole answer — in that example, `clcik` should be `click`.

---

### You deleted most of the config by accident

```bash
rm ~/.config/hypr/hyprland.lua
Hyprland
```

Hyprland regenerates a complete default. **Back up before every edit:**

```bash
cp ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.bak
```

---

### `Ctrl+C` closed Firefox instead of copying

`Ctrl+C` in a terminal sends an interrupt signal. If you launched Firefox from that
terminal, it kills Firefox.

| Action | Correct shortcut |
|---|---|
| Copy in kitty | `Ctrl + Shift + C` |
| Paste in kitty | `Ctrl + Shift + V` |

Launch GUI apps detached:

```bash
firefox &
disown
```

---

### Selecting text does not copy on Wayland

```bash
sudo pacman -S wl-clipboard
```

Or bypass selection entirely:

```bash
wl-copy < ~/.ssh/id_ed25519.pub
```

---

## Git and SSH

### `error: remote origin already exists`

```bash
git remote -v                                              # see what it points at
git remote set-url origin git@github.com:USER/repo.git     # change it
git remote -v                                              # verify
```

`set-url` modifies an existing remote; `add` only works for a new one.

---

### GitHub rejects the SSH key: "Key is invalid. You must supply a key in openssh public key format"

**Almost always a transcription error.** Verify your key is well-formed first:

```bash
ssh-keygen -l -f ~/.ssh/id_ed25519.pub
```

If that prints a fingerprint, the file is fine and the problem is in what you pasted.

**Common causes:**

| Cause | Detail |
|---|---|
| Wrong file | `cat ~/.ssh/id_ed25519` without `.pub` gives the **private** key, starting `-----BEGIN OPENSSH PRIVATE KEY-----`. GitHub rejects it with exactly this error |
| Line breaks | The key must be **one unbroken line**. A visual wrap typed as a newline breaks it |
| Character confusion | `l` vs `1` vs `I`, `0` vs `O` in base64 |

> **If you pasted your private key anywhere, treat it as compromised.** Delete the pair and
> regenerate:
>
> ```bash
> rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
> ssh-keygen -t ed25519 -C "your@email.com"
> ```

**The real fix: do not transcribe it by hand.** Install Firefox, then
`wl-copy < ~/.ssh/id_ed25519.pub` and paste with `Ctrl+V`.

**Keep the email comment at the end** — it is a normal part of the format, not the problem.

---

### `ssh-keygen: command not found`

```bash
sudo pacman -S openssh
```

Not part of the Arch base package. You only need the client; no need to enable `sshd`
unless you want to connect *into* this machine.

---

### GitHub does not accept your password

It stopped accepting account passwords for git operations in 2021, and signing in with
Google means you have no password anyway. Use an SSH key (preferred) or a
[Personal Access Token](https://github.com/settings/tokens) with the `repo` scope.

---

## Typos that cost real time during this build

Every one of these produced a confusing failure. They are listed because the pattern
matters more than any individual case.

| Typed | Should be | What happened |
|---|---|---|
| `--chnage-name` | `--change-name` | `sgdisk` exited silently without creating the partition |
| `mkfs.fat -n EFI` | `mkfs.fat -F32 -n EFI` | Possibly FAT16, which UEFI can refuse to boot |
| `mirroelist` | `mirrorlist` | Created a junk file; real mirror list never updated |
| `initd` | `initrd` | Microcode would not load at boot |
| `arch.cong` | `arch.conf` | Broken boot entry sitting alongside the real one |
| `tap_to_clcik` | `tap_to_click` | Hyprland config error |
| `umount R /mnt` | `umount -R /mnt` | Unmount failed, risking an unclean FAT32 write |
| `mobprobe` | `modprobe` | Module never loaded |
| `hod_multitouch` | `hid_multitouch` | The check silently found nothing, so a failed load looked successful |
| `git log --online` | `git log --oneline` | `fatal: unrecognized argument` |
| `pacman -s` | `pacman -S` | `error: invalid option` — case matters |
| `.gitinore` | `.gitignore` | Git ignored nothing at all |
| `grep "^server"` | `grep "^Server"` | Returned `0`, making a healthy mirror list look empty |

See [`LESSONS.md`](LESSONS.md) for the habits that prevent these.
