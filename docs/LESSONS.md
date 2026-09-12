# Lessons

Habits that would have saved hours on this build. Written down because the pattern matters
more than any individual mistake.

---

## Read the error before doing anything else

Linux tools are usually specific about what went wrong. Several rounds of debugging in this
build happened because an error message was scrolled past rather than read.

Examples where the message contained the entire answer:

```
Unknown option: chnage-name
```

```
/home/sourav/.config/hypr/hyprland.lua:226: unknown config key 'input.touchpad.tap_to_clcik'
```

```
paru: error while loading shared libraries: libalpm.so.15: cannot open shared object file
```

```
cat: /boot/loader/entries/arch-lts.conf: No such file or directory
```

Each named the exact file, key, line number or library. **Read it first, not second.**

---

## Read commands backwards before pressing Enter

Paths and filenames sit at the end of a command, and that is where typos hide. After typing
something long, scan it from the end back to the start.

`Home` jumps to the beginning of the line; arrow keys scan across.

---

## Use Tab completion for every path

The shell completes file paths for you. Type a short prefix and press **Tab**:

```bash
/etc/pacman.d/mirr<Tab>     →  /etc/pacman.d/mirrorlist
```

This is the single best defence against path typos, and it would have prevented
`mirroelist`, `arch.cong` and `/boott/` in this build.

**Tab does not help inside command words** — only with paths. For those, slow down.

---

## Shorten your search strings

Instead of typing a long key name you might misspell:

```bash
grep Parallel /etc/pacman.conf        # not ParallelDownloads
```

grep matches partial words. Less to type is less to get wrong.

---

## Back up before every config edit

```bash
cp file file.bak
```

One second of work. Restoring is one command. During this build the Hyprland config was
reduced to a fragment with no keybinds, which would have left a desktop with no way to open
a terminal.

Git does this properly once your configs are in the repo — but `.bak` covers you in the gap
before that.

---

## Do not retype anything long

Manual transcription of a 100-character SSH key through a phone camera is not a reasonable
task. `l`/`1`/`I` and `0`/`O` are genuinely ambiguous in base64 on a console font.

When you find yourself transcribing something long, stop and find a copy-paste path
instead — even if that means installing a browser first.

The same applies to UUIDs. Generate config files with command substitution rather than
typing the value:

```bash
options root=UUID=$(blkid -s UUID -o value /dev/nvme0n1p2) rootflags=subvol=@ rw
```

---

## Do not edit a recalled command into a different one

Pressing Up and modifying a previous command is how the LTS boot entry got written into
`arch.conf` twice. When you need a genuinely different command, type it fresh.

---

## `>` overwrites, `>>` appends

```bash
genfstab -U /mnt >> /mnt/etc/fstab     # correct
genfstab -U /mnt > /mnt/etc/fstab      # wipes the file first
```

And `cat > file << EOF` replaces the entire file, which is useful for rewriting a broken
config but destructive if you meant to add something.

---

## Formatting is idempotent; `dd` is not

Re-running `mkfs.fat`, `mkfs.btrfs` or `mkfs.ext4` just produces the same clean result. If
you are unsure whether a format did what you wanted, redo it — it costs nothing before you
have written data.

The commands where a mistake actually matters:

- `dd` to the wrong device
- `rm -rf` on real data
- `arch-chroot` operations on a system you have already built

---

## Check the state before assuming a command failed

Several times in this build a command "failed" but had actually done nothing, or had
succeeded silently:

- `sgdisk` with a bad flag exits **before touching the disk** — nothing happened, rather
  than something happening wrongly
- `umount -R /mnt` returning no output means **success**
- `grep -c "^server"` returning `0` means the case was wrong, not that the file is empty
- `lsmod | grep hid_multitouch` showing usage count `0` means the module loaded but **bound
  to nothing** — which looks like success and is not

Verify with a second command rather than inferring.

---

## Cold power-off fixes more than you expect

I2C and USB devices are not always fully reset by a warm reboot. The touchpad in this build
was stuck in a state left behind by Windows and came back to life after a complete
shutdown — after an evening of driver debugging that found nothing wrong.

**For input or USB hardware behaving strangely, try a full power-off before a deep dive.**

---

## Prefer source packages over `-bin` on a rolling release

`paru-bin` installed in seconds and did not run, because it was linked against
`libalpm.so.15` while the system had `.16`. Building from source took 25 minutes and
worked.

`-bin` packages break whenever the library they were compiled against changes. On Arch,
that is often.

---

## Understand what a tool refuses to do, and why

`bootctl install` inside a chroot prints:

```
Not booted with EFI or running in a container, skipping EFI variable modifications.
```

That single line explained four failed boot attempts. It was visible from the first
attempt. The fix — running `efibootmgr` from the live environment *outside* the chroot —
followed directly from understanding what the message meant.

---

## Know when to stop

Several hours went into the touchpad while a working USB mouse sat on the desk. The
touchpad was a comfort feature, not a blocker.

When you have a workaround and the remaining problem is a hardware quirk, note it, move on,
and come back fresh. Some problems also fix themselves with a kernel update or, as here, a
power cycle.

---

## Keep a record as you go

This document exists because the build was documented while it happened. The value is not
in the successes — those are in every guide. It is in the four failed bootloader attempts,
the library version mismatch, and the touchpad that reported contact but no coordinates.

Those are the parts that make a guide useful to someone else.
